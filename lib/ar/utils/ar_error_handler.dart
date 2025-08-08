import 'package:flutter/material.dart';

/// Enum for different types of AR errors
enum ARErrorType {
  initialization,
  sessionStart,
  sessionPause,
  sessionResume,
  sessionStop,
  modelLoading,
  modelPlacement,
  hitTesting,
  resourceManagement,
  deviceCompatibility,
  permissions,
  networkConnection,
  thermalThrottling,
  memoryPressure,
  unknown,
}

/// Class representing an AR error with context
class ARError {
  final ARErrorType type;
  final String message;
  final String? details;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic>? context;

  ARError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
    this.stackTrace,
    DateTime? timestamp,
    this.context,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create an ARError from a generic exception
  factory ARError.fromException(
    Exception exception, {
    ARErrorType type = ARErrorType.unknown,
    String? customMessage,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    return ARError(
      type: type,
      message: customMessage ?? exception.toString(),
      details: exception.toString(),
      originalError: exception,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (type) {
      case ARErrorType.initialization:
        return 'Failed to initialize AR. Please try again.';
      case ARErrorType.sessionStart:
        return 'Could not start AR session. Please restart the app.';
      case ARErrorType.sessionPause:
        return 'AR session paused due to system requirements.';
      case ARErrorType.sessionResume:
        return 'Could not resume AR session. Please try again.';
      case ARErrorType.sessionStop:
        return 'AR session stopped unexpectedly.';
      case ARErrorType.modelLoading:
        return 'Failed to load 3D model. Please check your connection.';
      case ARErrorType.modelPlacement:
        return 'Could not place 3D model in AR space.';
      case ARErrorType.hitTesting:
        return 'Touch interaction temporarily unavailable.';
      case ARErrorType.resourceManagement:
        return 'System resources are low. AR quality may be reduced.';
      case ARErrorType.deviceCompatibility:
        return 'This device does not support AR features.';
      case ARErrorType.permissions:
        return 'Camera permission is required for AR features.';
      case ARErrorType.networkConnection:
        return 'Network connection required for some AR features.';
      case ARErrorType.thermalThrottling:
        return 'Device is overheating. AR features have been reduced.';
      case ARErrorType.memoryPressure:
        return 'Low memory detected. AR quality has been reduced.';
      case ARErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get recovery suggestion for the user
  String get recoverySuggestion {
    switch (type) {
      case ARErrorType.initialization:
        return 'Try restarting the app or check if your device supports AR.';
      case ARErrorType.sessionStart:
        return 'Close other apps and try again.';
      case ARErrorType.sessionPause:
        return 'AR will resume automatically when conditions improve.';
      case ARErrorType.sessionResume:
        return 'Wait a moment and try again.';
      case ARErrorType.sessionStop:
        return 'Tap to restart AR session.';
      case ARErrorType.modelLoading:
        return 'Check your internet connection and try again.';
      case ARErrorType.modelPlacement:
        return 'Move your device slowly and ensure good lighting.';
      case ARErrorType.hitTesting:
        return 'Try tapping on the 3D model again.';
      case ARErrorType.resourceManagement:
        return 'Close other apps to improve performance.';
      case ARErrorType.deviceCompatibility:
        return 'Use the standard camera mode instead.';
      case ARErrorType.permissions:
        return 'Grant camera permission in device settings.';
      case ARErrorType.networkConnection:
        return 'Connect to the internet and try again.';
      case ARErrorType.thermalThrottling:
        return 'Let your device cool down before using AR again.';
      case ARErrorType.memoryPressure:
        return 'Close other apps to free up memory.';
      case ARErrorType.unknown:
        return 'If the problem persists, please restart the app.';
    }
  }

  /// Check if this error is recoverable
  bool get isRecoverable {
    switch (type) {
      case ARErrorType.deviceCompatibility:
      case ARErrorType.permissions:
        return false;
      default:
        return true;
    }
  }

  /// Check if this error should be shown to the user
  bool get shouldShowToUser {
    switch (type) {
      case ARErrorType.hitTesting:
        return false; // These are too frequent and not critical
      default:
        return true;
    }
  }

  @override
  String toString() {
    return 'ARError(type: $type, message: $message, timestamp: $timestamp)';
  }
}

/// Callback type for error recovery actions
typedef ErrorRecoveryCallback = Future<bool> Function();

/// Service for handling AR errors with logging and user feedback
class ARErrorHandler {
  static final ARErrorHandler _instance = ARErrorHandler._internal();
  factory ARErrorHandler() => _instance;
  ARErrorHandler._internal();

  // Error history for debugging
  final List<ARError> _errorHistory = [];

  // Maximum number of errors to keep in history
  static const int _maxErrorHistory = 50;

  // Error listeners
  final List<Function(ARError)> _errorListeners = [];

  /// Add an error listener
  void addErrorListener(Function(ARError) listener) {
    _errorListeners.add(listener);
  }

  /// Remove an error listener
  void removeErrorListener(Function(ARError) listener) {
    _errorListeners.remove(listener);
  }

  /// Handle an AR error with comprehensive logging and user feedback
  Future<void> handleError(
    ARError error, {
    BuildContext? context,
    ErrorRecoveryCallback? onRetry,
    bool showUserFeedback = true,
  }) async {
    // Add to error history
    _addToHistory(error);

    // Log the error
    _logError(error);

    // Notify listeners
    for (final listener in _errorListeners) {
      try {
        listener(error);
      } catch (e) {
        debugPrint('Error in error listener: $e');
      }
    }

    // Show user feedback if requested and context is available
    if (showUserFeedback &&
        context != null &&
        error.shouldShowToUser &&
        context.mounted) {
      await _showUserFeedback(context, error, onRetry);
    }

    // Perform automatic recovery if possible
    await _attemptAutomaticRecovery(error);
  }

  /// Handle an exception and convert it to an ARError
  Future<void> handleException(
    Exception exception, {
    ARErrorType type = ARErrorType.unknown,
    String? customMessage,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
    BuildContext? buildContext,
    ErrorRecoveryCallback? onRetry,
    bool showUserFeedback = true,
  }) async {
    final error = ARError.fromException(
      exception,
      type: type,
      customMessage: customMessage,
      context: context,
      stackTrace: stackTrace,
    );

    await handleError(
      error,
      context: buildContext,
      onRetry: onRetry,
      showUserFeedback: showUserFeedback,
    );
  }

  /// Add error to history with size limit
  void _addToHistory(ARError error) {
    _errorHistory.add(error);

    // Keep only the most recent errors
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  /// Log error with appropriate level and structured format
  void _logError(ARError error) {
    final logMessage = '''
AR Error Occurred:
  Type: ${error.type}
  Message: ${error.message}
  Details: ${error.details ?? 'None'}
  Timestamp: ${error.timestamp}
  Context: ${error.context ?? 'None'}
  Original Error: ${error.originalError ?? 'None'}
  Recoverable: ${error.isRecoverable}
  Show to User: ${error.shouldShowToUser}
''';

    // Use different log levels based on error severity
    switch (error.type) {
      case ARErrorType.deviceCompatibility:
      case ARErrorType.permissions:
        debugPrint('AR INFO: $logMessage');
        break;
      case ARErrorType.hitTesting:
      case ARErrorType.sessionPause:
        debugPrint('AR DEBUG: $logMessage');
        break;
      case ARErrorType.thermalThrottling:
      case ARErrorType.memoryPressure:
      case ARErrorType.resourceManagement:
        debugPrint('AR WARNING: $logMessage');
        break;
      default:
        debugPrint('AR ERROR: $logMessage');
        break;
    }

    // Print stack trace for critical errors
    if (error.stackTrace != null && _isCriticalError(error.type)) {
      debugPrint('Stack trace: ${error.stackTrace}');
    }

    // Log to system if available (for production debugging)
    _logToSystem(error);
  }

  /// Log error to system for production debugging
  void _logToSystem(ARError error) {
    // In a production app, this could send to crash reporting services
    // For now, we'll just ensure it's properly formatted for debugging
    try {
      final systemLogData = {
        'timestamp': error.timestamp.toIso8601String(),
        'type': error.type.toString(),
        'message': error.message,
        'details': error.details,
        'context': error.context,
        'recoverable': error.isRecoverable,
        'critical': _isCriticalError(error.type),
      };

      // This could be sent to Firebase Crashlytics, Sentry, etc.
      debugPrint('SYSTEM_LOG: ${systemLogData.toString()}');
    } catch (e) {
      debugPrint('Failed to log error to system: $e');
    }
  }

  /// Check if an error type is critical
  bool _isCriticalError(ARErrorType type) {
    switch (type) {
      case ARErrorType.initialization:
      case ARErrorType.sessionStart:
      case ARErrorType.deviceCompatibility:
        return true;
      default:
        return false;
    }
  }

  /// Show user feedback for the error
  Future<void> _showUserFeedback(
    BuildContext context,
    ARError error,
    ErrorRecoveryCallback? onRetry,
  ) async {
    if (!context.mounted) return;

    // For critical errors, show a dialog
    if (_isCriticalError(error.type)) {
      await _showErrorDialog(context, error, onRetry);
    } else {
      // For non-critical errors, show a snackbar
      _showErrorSnackBar(context, error, onRetry);
    }
  }

  /// Show error dialog for critical errors
  Future<void> _showErrorDialog(
    BuildContext context,
    ARError error,
    ErrorRecoveryCallback? onRetry,
  ) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getErrorIcon(error.type),
                color: _getErrorColor(error.type),
              ),
              const SizedBox(width: 8),
              const Text('AR Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error.userFriendlyMessage,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                error.recoverySuggestion,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            if (error.isRecoverable && onRetry != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final success = await onRetry();
                  if (!success && context.mounted) {
                    // If retry failed, show another error
                    await handleError(
                      ARError(
                        type: ARErrorType.unknown,
                        message: 'Retry failed',
                        details: 'The retry operation did not succeed',
                      ),
                      context: context,
                      showUserFeedback: false, // Avoid infinite loops
                    );
                  }
                },
                child: const Text('Retry'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show error snackbar for non-critical errors
  void _showErrorSnackBar(
    BuildContext context,
    ARError error,
    ErrorRecoveryCallback? onRetry,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.userFriendlyMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (error.recoverySuggestion.isNotEmpty)
                    Text(
                      error.recoverySuggestion,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: error.isRecoverable && onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () async {
                  final success = await onRetry();
                  if (!success && context.mounted) {
                    _showErrorSnackBar(
                      context,
                      ARError(
                        type: ARErrorType.unknown,
                        message: 'Retry failed',
                      ),
                      null,
                    );
                  }
                },
              )
            : null,
      ),
    );
  }

  /// Get appropriate icon for error type
  IconData _getErrorIcon(ARErrorType type) {
    switch (type) {
      case ARErrorType.initialization:
      case ARErrorType.sessionStart:
        return Icons.error_outline;
      case ARErrorType.deviceCompatibility:
        return Icons.phone_android;
      case ARErrorType.permissions:
        return Icons.camera_alt;
      case ARErrorType.networkConnection:
        return Icons.wifi_off;
      case ARErrorType.thermalThrottling:
        return Icons.device_thermostat;
      case ARErrorType.memoryPressure:
        return Icons.memory;
      case ARErrorType.modelLoading:
        return Icons.download;
      case ARErrorType.resourceManagement:
        return Icons.warning;
      default:
        return Icons.info_outline;
    }
  }

  /// Get appropriate color for error type
  Color _getErrorColor(ARErrorType type) {
    switch (type) {
      case ARErrorType.initialization:
      case ARErrorType.sessionStart:
      case ARErrorType.deviceCompatibility:
      case ARErrorType.permissions:
        return Colors.red;
      case ARErrorType.thermalThrottling:
      case ARErrorType.memoryPressure:
      case ARErrorType.resourceManagement:
        return Colors.orange;
      case ARErrorType.networkConnection:
      case ARErrorType.modelLoading:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Attempt automatic recovery for certain error types
  Future<void> _attemptAutomaticRecovery(ARError error) async {
    switch (error.type) {
      case ARErrorType.sessionPause:
        // Automatic resume will be handled by lifecycle management
        debugPrint('AR session paused - automatic resume will be attempted');
        break;
      case ARErrorType.memoryPressure:
        // Trigger resource cleanup
        debugPrint('Memory pressure detected - triggering resource cleanup');
        // This would be handled by ResourceManager
        break;
      case ARErrorType.thermalThrottling:
        // Reduce AR quality automatically
        debugPrint('Thermal throttling detected - reducing AR quality');
        // This would be handled by ThermalManager
        break;
      default:
        // No automatic recovery available
        break;
    }
  }

  /// Get error history for debugging
  List<ARError> get errorHistory => List.unmodifiable(_errorHistory);

  /// Clear error history
  void clearHistory() {
    _errorHistory.clear();
  }

  /// Get error statistics
  Map<ARErrorType, int> getErrorStatistics() {
    final stats = <ARErrorType, int>{};
    for (final error in _errorHistory) {
      stats[error.type] = (stats[error.type] ?? 0) + 1;
    }
    return stats;
  }

  /// Check if there have been recent errors of a specific type
  bool hasRecentErrors(ARErrorType type,
      {Duration within = const Duration(minutes: 5)}) {
    final cutoff = DateTime.now().subtract(within);
    return _errorHistory
        .any((error) => error.type == type && error.timestamp.isAfter(cutoff));
  }

  /// Get the most recent error of a specific type
  ARError? getLastError(ARErrorType type) {
    for (int i = _errorHistory.length - 1; i >= 0; i--) {
      if (_errorHistory[i].type == type) {
        return _errorHistory[i];
      }
    }
    return null;
  }
}
