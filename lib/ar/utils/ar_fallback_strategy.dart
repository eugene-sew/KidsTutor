import 'package:flutter/material.dart';
import 'dart:async';
import 'ar_error_handler.dart';
import 'settings_service.dart';

/// Enum for different fallback strategies
enum FallbackStrategy {
  /// Show 2D alternative UI
  fallbackUI,

  /// Show error message and retry option
  errorWithRetry,

  /// Show minimal error notification
  minimalError,

  /// Attempt automatic recovery
  autoRecover,

  /// Graceful degradation (reduced functionality)
  gracefulDegradation,
}

/// Configuration for fallback behavior
class FallbackConfig {
  final FallbackStrategy strategy;
  final Duration? retryDelay;
  final int maxRetries;
  final bool showUserNotification;
  final String? customMessage;
  final VoidCallback? onFallback;

  const FallbackConfig({
    required this.strategy,
    this.retryDelay,
    this.maxRetries = 3,
    this.showUserNotification = true,
    this.customMessage,
    this.onFallback,
  });
}

/// Service for managing AR fallback strategies
class ARFallbackStrategy {
  static final ARFallbackStrategy _instance = ARFallbackStrategy._internal();
  factory ARFallbackStrategy() => _instance;
  ARFallbackStrategy._internal();

  // Configuration for different error types
  final Map<ARErrorType, FallbackConfig> _fallbackConfigs = {
    // Permanent failures - show fallback UI
    ARErrorType.deviceCompatibility: const FallbackConfig(
      strategy: FallbackStrategy.fallbackUI,
      showUserNotification: true,
    ),
    ARErrorType.permissions: const FallbackConfig(
      strategy: FallbackStrategy.errorWithRetry,
      showUserNotification: true,
      maxRetries: 1,
    ),

    // Initialization failures - retry with fallback
    ARErrorType.initialization: const FallbackConfig(
      strategy: FallbackStrategy.errorWithRetry,
      retryDelay: Duration(seconds: 5),
      maxRetries: 3,
    ),
    ARErrorType.sessionStart: const FallbackConfig(
      strategy: FallbackStrategy.errorWithRetry,
      retryDelay: Duration(seconds: 3),
      maxRetries: 2,
    ),

    // Temporary failures - auto recover
    ARErrorType.thermalThrottling: const FallbackConfig(
      strategy: FallbackStrategy.autoRecover,
      retryDelay: Duration(minutes: 2),
      maxRetries: 2,
    ),
    ARErrorType.memoryPressure: const FallbackConfig(
      strategy: FallbackStrategy.autoRecover,
      retryDelay: Duration(seconds: 30),
      maxRetries: 3,
    ),

    // Session issues - graceful degradation
    ARErrorType.sessionPause: const FallbackConfig(
      strategy: FallbackStrategy.gracefulDegradation,
      retryDelay: Duration(seconds: 5),
      showUserNotification: false,
    ),
    ARErrorType.sessionResume: const FallbackConfig(
      strategy: FallbackStrategy.autoRecover,
      retryDelay: Duration(seconds: 2),
      maxRetries: 3,
      showUserNotification: false,
    ),

    // Resource issues - graceful degradation
    ARErrorType.resourceManagement: const FallbackConfig(
      strategy: FallbackStrategy.gracefulDegradation,
      retryDelay: Duration(seconds: 15),
      maxRetries: 2,
    ),

    // Model loading - minimal error
    ARErrorType.modelLoading: const FallbackConfig(
      strategy: FallbackStrategy.minimalError,
      retryDelay: Duration(seconds: 3),
      maxRetries: 2,
      showUserNotification: false,
    ),

    // Network issues - minimal error
    ARErrorType.networkConnection: const FallbackConfig(
      strategy: FallbackStrategy.minimalError,
      showUserNotification: true,
      maxRetries: 1,
    ),

    // Hit testing - no fallback needed
    ARErrorType.hitTesting: const FallbackConfig(
      strategy: FallbackStrategy.minimalError,
      showUserNotification: false,
      maxRetries: 0,
    ),

    // Unknown errors - error with retry
    ARErrorType.unknown: const FallbackConfig(
      strategy: FallbackStrategy.errorWithRetry,
      retryDelay: Duration(seconds: 5),
      maxRetries: 2,
    ),
  };

  // Active timers for auto-recovery
  final Map<ARErrorType, Timer> _recoveryTimers = {};

  // Retry counters
  final Map<ARErrorType, int> _retryCounts = {};

  /// Get fallback configuration for an error type
  FallbackConfig getFallbackConfig(ARErrorType errorType) {
    return _fallbackConfigs[errorType] ??
        _fallbackConfigs[ARErrorType.unknown]!;
  }

  /// Determine if fallback UI should be shown
  bool shouldShowFallbackUI(ARError error) {
    final config = getFallbackConfig(error.type);
    return config.strategy == FallbackStrategy.fallbackUI ||
        (config.strategy == FallbackStrategy.errorWithRetry &&
            _hasExceededRetries(error.type, config.maxRetries));
  }

  /// Determine if automatic recovery should be attempted
  bool shouldAttemptAutoRecovery(ARError error) {
    final config = getFallbackConfig(error.type);
    return config.strategy == FallbackStrategy.autoRecover &&
        !_hasExceededRetries(error.type, config.maxRetries);
  }

  /// Determine if graceful degradation should be applied
  bool shouldApplyGracefulDegradation(ARError error) {
    final config = getFallbackConfig(error.type);
    return config.strategy == FallbackStrategy.gracefulDegradation;
  }

  /// Schedule automatic recovery for an error
  void scheduleAutoRecovery(
    ARError error,
    Future<bool> Function() recoveryFunction,
  ) {
    final config = getFallbackConfig(error.type);

    if (config.strategy != FallbackStrategy.autoRecover ||
        _hasExceededRetries(error.type, config.maxRetries)) {
      return;
    }

    // Cancel existing timer for this error type
    _recoveryTimers[error.type]?.cancel();

    final delay = config.retryDelay ?? const Duration(seconds: 10);

    debugPrint(
        'Scheduling auto-recovery for ${error.type} in ${delay.inSeconds}s');

    _recoveryTimers[error.type] = Timer(delay, () async {
      _incrementRetryCount(error.type);

      try {
        final success = await recoveryFunction();
        if (success) {
          debugPrint('Auto-recovery successful for ${error.type}');
          _resetRetryCount(error.type);
        } else {
          debugPrint('Auto-recovery failed for ${error.type}');
          // Schedule another attempt if retries remain
          if (!_hasExceededRetries(error.type, config.maxRetries)) {
            scheduleAutoRecovery(error, recoveryFunction);
          }
        }
      } catch (e) {
        debugPrint('Error during auto-recovery for ${error.type}: $e');
      }
    });
  }

  /// Get user-friendly fallback message
  String getFallbackMessage(ARError error) {
    final config = getFallbackConfig(error.type);

    if (config.customMessage != null) {
      return config.customMessage!;
    }

    switch (config.strategy) {
      case FallbackStrategy.fallbackUI:
        return _getPermanentFallbackMessage(error.type);
      case FallbackStrategy.errorWithRetry:
        return _getRetryableErrorMessage(error.type);
      case FallbackStrategy.autoRecover:
        return _getAutoRecoveryMessage(error.type);
      case FallbackStrategy.gracefulDegradation:
        return _getGracefulDegradationMessage(error.type);
      case FallbackStrategy.minimalError:
        return error.userFriendlyMessage;
    }
  }

  /// Get permanent fallback message
  String _getPermanentFallbackMessage(ARErrorType errorType) {
    switch (errorType) {
      case ARErrorType.deviceCompatibility:
        return 'AR is not supported on this device. Using standard camera mode.';
      case ARErrorType.permissions:
        return 'Camera permission required for AR. Using standard mode.';
      default:
        return 'AR is temporarily unavailable. Using standard camera mode.';
    }
  }

  /// Get retryable error message
  String _getRetryableErrorMessage(ARErrorType errorType) {
    switch (errorType) {
      case ARErrorType.initialization:
        return 'Failed to start AR. Tap to retry.';
      case ARErrorType.sessionStart:
        return 'AR session failed to start. Tap to retry.';
      default:
        return 'AR encountered an issue. Tap to retry.';
    }
  }

  /// Get auto-recovery message
  String _getAutoRecoveryMessage(ARErrorType errorType) {
    switch (errorType) {
      case ARErrorType.thermalThrottling:
        return 'Device is cooling down. AR will resume automatically.';
      case ARErrorType.memoryPressure:
        return 'Optimizing memory usage. AR will resume shortly.';
      default:
        return 'AR is recovering. Please wait...';
    }
  }

  /// Get graceful degradation message
  String _getGracefulDegradationMessage(ARErrorType errorType) {
    switch (errorType) {
      case ARErrorType.sessionPause:
        return 'AR paused temporarily. Functionality will resume automatically.';
      case ARErrorType.resourceManagement:
        return 'AR running in reduced quality mode to optimize performance.';
      default:
        return 'AR running with reduced functionality.';
    }
  }

  /// Check if retries have been exceeded
  bool _hasExceededRetries(ARErrorType errorType, int maxRetries) {
    return (_retryCounts[errorType] ?? 0) >= maxRetries;
  }

  /// Increment retry count
  void _incrementRetryCount(ARErrorType errorType) {
    _retryCounts[errorType] = (_retryCounts[errorType] ?? 0) + 1;
  }

  /// Reset retry count
  void _resetRetryCount(ARErrorType errorType) {
    _retryCounts[errorType] = 0;
  }

  /// Get current retry count
  int getRetryCount(ARErrorType errorType) {
    return _retryCounts[errorType] ?? 0;
  }

  /// Check if retry is available
  bool canRetry(ARErrorType errorType) {
    final config = getFallbackConfig(errorType);
    return !_hasExceededRetries(errorType, config.maxRetries);
  }

  /// Cancel all recovery timers
  void cancelAllRecoveryTimers() {
    for (final timer in _recoveryTimers.values) {
      timer.cancel();
    }
    _recoveryTimers.clear();
  }

  /// Reset all retry counts
  void resetAllRetryCounts() {
    _retryCounts.clear();
  }

  /// Get fallback statistics
  Map<String, dynamic> getFallbackStatistics() {
    return {
      'activeRecoveryTimers': _recoveryTimers.length,
      'retryCounts': _retryCounts.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'fallbackConfigs': _fallbackConfigs.map(
        (key, value) => MapEntry(key.toString(), {
          'strategy': value.strategy.toString(),
          'maxRetries': value.maxRetries,
          'retryDelay': value.retryDelay?.inSeconds,
        }),
      ),
    };
  }

  /// Dispose the fallback strategy service
  void dispose() {
    cancelAllRecoveryTimers();
    resetAllRetryCounts();
  }
}
