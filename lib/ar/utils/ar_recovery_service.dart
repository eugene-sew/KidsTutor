import 'package:flutter/material.dart';
import 'dart:async';
import 'ar_error_handler.dart';
import 'ar_manager.dart';
import 'model_manager.dart';
import 'resource_manager.dart';
import 'thermal_manager.dart';

/// Service for handling AR error recovery and automatic retry mechanisms
class ARRecoveryService {
  static final ARRecoveryService _instance = ARRecoveryService._internal();
  factory ARRecoveryService() => _instance;
  ARRecoveryService._internal();

  // Dependencies
  final ARErrorHandler _errorHandler = ARErrorHandler();
  final ARManager _arManager = ARManager();
  final ResourceManager _resourceManager = ResourceManager();
  final ThermalManager _thermalManager = ThermalManager();

  // Recovery state
  bool _isRecovering = false;
  int _recoveryAttempts = 0;
  static const int _maxRecoveryAttempts = 3;
  Timer? _recoveryTimer;
  final Map<ARErrorType, DateTime> _lastErrorTimes = {};
  final Map<ARErrorType, int> _errorCounts = {};

  // Recovery callbacks
  final List<VoidCallback> _recoveryListeners = [];

  /// Initialize the recovery service
  Future<void> initialize() async {
    // Listen for errors that need recovery
    _errorHandler.addErrorListener(_handleErrorForRecovery);

    // Start monitoring system health
    _startHealthMonitoring();
  }

  /// Add a recovery listener
  void addRecoveryListener(VoidCallback listener) {
    _recoveryListeners.add(listener);
  }

  /// Remove a recovery listener
  void removeRecoveryListener(VoidCallback listener) {
    _recoveryListeners.remove(listener);
  }

  /// Handle errors that might need recovery
  void _handleErrorForRecovery(ARError error) {
    // Track error frequency
    _trackError(error);

    // Check if this error type needs automatic recovery
    if (_shouldAttemptRecovery(error)) {
      _scheduleRecovery(error);
    }
  }

  /// Track error occurrence for pattern analysis
  void _trackError(ARError error) {
    _lastErrorTimes[error.type] = DateTime.now();
    _errorCounts[error.type] = (_errorCounts[error.type] ?? 0) + 1;
  }

  /// Check if we should attempt recovery for this error
  bool _shouldAttemptRecovery(ARError error) {
    // Don't recover if already recovering
    if (_isRecovering) return false;

    // Don't recover if max attempts reached
    if (_recoveryAttempts >= _maxRecoveryAttempts) return false;

    // Check error type
    switch (error.type) {
      case ARErrorType.sessionStart:
      case ARErrorType.sessionPause:
      case ARErrorType.sessionResume:
      case ARErrorType.modelLoading:
      case ARErrorType.memoryPressure:
      case ARErrorType.thermalThrottling:
      case ARErrorType.resourceManagement:
        return true;
      case ARErrorType.deviceCompatibility:
      case ARErrorType.permissions:
        return false; // These are permanent failures
      default:
        return error.isRecoverable;
    }
  }

  /// Schedule recovery attempt
  void _scheduleRecovery(ARError error) {
    // Cancel any existing recovery timer
    _recoveryTimer?.cancel();

    // Calculate delay based on error type and attempt count
    final delay = _calculateRecoveryDelay(error);

    debugPrint(
        'Scheduling AR recovery for ${error.type} in ${delay.inSeconds}s');

    _recoveryTimer = Timer(delay, () {
      _attemptRecovery(error);
    });
  }

  /// Calculate appropriate delay for recovery
  Duration _calculateRecoveryDelay(ARError error) {
    final baseDelay = switch (error.type) {
      ARErrorType.thermalThrottling => const Duration(minutes: 2),
      ARErrorType.memoryPressure => const Duration(seconds: 30),
      ARErrorType.sessionPause => const Duration(seconds: 5),
      ARErrorType.resourceManagement => const Duration(seconds: 15),
      _ => const Duration(seconds: 10),
    };

    // Exponential backoff based on attempt count
    final multiplier = (1 << _recoveryAttempts).clamp(1, 8);
    return Duration(milliseconds: (baseDelay.inMilliseconds * multiplier));
  }

  /// Attempt to recover from the error
  Future<void> _attemptRecovery(ARError error) async {
    if (_isRecovering) return;

    _isRecovering = true;
    _recoveryAttempts++;

    debugPrint(
        'Attempting AR recovery for ${error.type} (attempt $_recoveryAttempts)');

    try {
      bool recoverySuccess = false;

      switch (error.type) {
        case ARErrorType.sessionStart:
        case ARErrorType.sessionResume:
          recoverySuccess = await _recoverARSession();
          break;
        case ARErrorType.sessionPause:
          recoverySuccess = await _resumeARSession();
          break;
        case ARErrorType.modelLoading:
          recoverySuccess = await _recoverModelLoading();
          break;
        case ARErrorType.memoryPressure:
          recoverySuccess = await _recoverFromMemoryPressure();
          break;
        case ARErrorType.thermalThrottling:
          recoverySuccess = await _recoverFromThermalThrottling();
          break;
        case ARErrorType.resourceManagement:
          recoverySuccess = await _recoverResourceManagement();
          break;
        default:
          recoverySuccess = await _genericRecovery();
          break;
      }

      if (recoverySuccess) {
        debugPrint('AR recovery successful for ${error.type}');
        _resetRecoveryState();
        _notifyRecoveryListeners();
      } else {
        debugPrint('AR recovery failed for ${error.type}');
        if (_recoveryAttempts < _maxRecoveryAttempts) {
          // Schedule another attempt
          _scheduleRecovery(error);
        } else {
          debugPrint('Max recovery attempts reached for ${error.type}');
          _resetRecoveryState();
        }
      }
    } catch (e) {
      debugPrint('Error during AR recovery: $e');
      _resetRecoveryState();
    } finally {
      _isRecovering = false;
    }
  }

  /// Recover AR session
  Future<bool> _recoverARSession() async {
    try {
      // Dispose current session
      _arManager.dispose();

      // Wait a moment
      await Future.delayed(const Duration(seconds: 2));

      // Reinitialize
      return await _arManager.initialize();
    } catch (e) {
      debugPrint('Failed to recover AR session: $e');
      return false;
    }
  }

  /// Resume AR session
  Future<bool> _resumeARSession() async {
    try {
      await _arManager.resumeSession();
      return true;
    } catch (e) {
      debugPrint('Failed to resume AR session: $e');
      return false;
    }
  }

  /// Recover from model loading issues
  Future<bool> _recoverModelLoading() async {
    try {
      // Clear model cache using ModelManager
      final modelManager = ModelManager();
      modelManager.clearCache();

      // Wait a moment
      await Future.delayed(const Duration(seconds: 1));

      // Models will be reloaded on next request
      return true;
    } catch (e) {
      debugPrint('Failed to recover model loading: $e');
      return false;
    }
  }

  /// Recover from memory pressure
  Future<bool> _recoverFromMemoryPressure() async {
    try {
      // Clear all caches using ModelManager
      final modelManager = ModelManager();
      modelManager.clearCache();

      // Note: ResourceManager doesn't have reduceQuality or forceGarbageCollection methods
      // These would need to be implemented if needed

      return true;
    } catch (e) {
      debugPrint('Failed to recover from memory pressure: $e');
      return false;
    }
  }

  /// Recover from thermal throttling
  Future<bool> _recoverFromThermalThrottling() async {
    try {
      // Check if device has cooled down
      final thermalState = _thermalManager.currentThermalState;

      if (thermalState == ThermalState.normal) {
        // Device has cooled down, restore normal operation
        // await _thermalManager.restoreNormalOperation();
        return true;
      } else {
        // Still too hot, wait longer
        return false;
      }
    } catch (e) {
      debugPrint('Failed to recover from thermal throttling: $e');
      return false;
    }
  }

  /// Recover resource management issues
  Future<bool> _recoverResourceManagement() async {
    try {
      // Clear unnecessary caches using ModelManager
      final modelManager = ModelManager();
      modelManager.clearCache();

      // Note: ResourceManager doesn't have optimizeResources method
      // This would need to be implemented if needed

      return true;
    } catch (e) {
      debugPrint('Failed to recover resource management: $e');
      return false;
    }
  }

  /// Generic recovery attempt
  Future<bool> _genericRecovery() async {
    try {
      // Try basic recovery steps
      final modelManager = ModelManager();
      modelManager.clearCache();
      await Future.delayed(const Duration(seconds: 2));
      return await _arManager.initialize();
    } catch (e) {
      debugPrint('Generic recovery failed: $e');
      return false;
    }
  }

  /// Reset recovery state after successful recovery
  void _resetRecoveryState() {
    _recoveryAttempts = 0;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
  }

  /// Notify recovery listeners
  void _notifyRecoveryListeners() {
    for (final listener in _recoveryListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error in recovery listener: $e');
      }
    }
  }

  /// Start monitoring system health for proactive recovery
  void _startHealthMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkSystemHealth();
    });
  }

  /// Check system health and perform proactive recovery if needed
  Future<void> _checkSystemHealth() async {
    try {
      // Check thermal state
      final thermalState = _thermalManager.currentThermalState;
      if (thermalState == ThermalState.critical) {
        await _errorHandler.handleError(
          ARError(
            type: ARErrorType.thermalThrottling,
            message: 'Device overheating detected',
            details: 'Proactive thermal management triggered',
          ),
          showUserFeedback: false,
        );
      }

      // Check memory usage (simplified check based on estimated usage)
      if (_resourceManager.estimatedMemoryUsage > 100) {
        // More than 100MB estimated usage
        await _errorHandler.handleError(
          ARError(
            type: ARErrorType.memoryPressure,
            message: 'High memory usage detected',
            details:
                'Estimated memory usage: ${_resourceManager.estimatedMemoryUsage} MB',
          ),
          showUserFeedback: false,
        );
      }
    } catch (e) {
      debugPrint('Error during health monitoring: $e');
    }
  }

  /// Get recovery statistics
  Map<String, dynamic> getRecoveryStatistics() {
    return {
      'isRecovering': _isRecovering,
      'recoveryAttempts': _recoveryAttempts,
      'maxRecoveryAttempts': _maxRecoveryAttempts,
      'errorCounts': Map.from(_errorCounts),
      'lastErrorTimes': _lastErrorTimes.map(
        (key, value) => MapEntry(key.toString(), value.toIso8601String()),
      ),
    };
  }

  /// Check if recovery is currently in progress
  bool get isRecovering => _isRecovering;

  /// Get the number of recovery attempts made
  int get recoveryAttempts => _recoveryAttempts;

  /// Reset all recovery statistics
  void resetStatistics() {
    _errorCounts.clear();
    _lastErrorTimes.clear();
    _resetRecoveryState();
  }

  /// Dispose the recovery service
  void dispose() {
    _recoveryTimer?.cancel();
    _recoveryListeners.clear();
    _errorCounts.clear();
    _lastErrorTimes.clear();
  }
}
