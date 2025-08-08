import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/ar_manager.dart';
import '../utils/ar_error_handler.dart';
import '../utils/ar_fallback_strategy.dart';
import '../utils/settings_service.dart';
import '../utils/resource_manager.dart';
import '../models/ar_model.dart';
import 'ar_view.dart';
import 'ar_fallback_ui.dart';

/// A wrapper widget for the AR view that handles AR availability checking
class ARViewWrapper extends StatefulWidget {
  /// List of object recognitions from the ML model
  final List<Map<String, dynamic>> recognitions;

  /// Callback when a model is interacted with
  final Function(ARModel model)? onModelInteraction;

  /// Constructor
  const ARViewWrapper({
    super.key,
    required this.recognitions,
    this.onModelInteraction,
  });

  @override
  _ARViewWrapperState createState() => _ARViewWrapperState();
}

class _ARViewWrapperState extends State<ARViewWrapper>
    with WidgetsBindingObserver {
  bool _isARAvailable = false;
  bool _isAREnabled = true;
  bool _isLoading = true;
  bool _showDebugInfo = false;
  bool _hasARError = false;
  String _fallbackReason = '';
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _autoRetryTimer;

  final ResourceManager _resourceManager = ResourceManager();
  final ARErrorHandler _errorHandler = ARErrorHandler();
  final ARManager _arManager = ARManager();
  final ARFallbackStrategy _fallbackStrategy = ARFallbackStrategy();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupErrorHandling();
    _checkARAvailability();
  }

  /// Setup error handling for AR failures using fallback strategy
  void _setupErrorHandling() {
    _errorHandler.addErrorListener((ARError error) {
      if (!mounted) return;

      // Use fallback strategy to determine appropriate response
      if (_fallbackStrategy.shouldShowFallbackUI(error)) {
        _showFallbackUI(error);
      } else if (_fallbackStrategy.shouldAttemptAutoRecovery(error)) {
        _scheduleAutoRecovery(error);
      } else if (_fallbackStrategy.shouldApplyGracefulDegradation(error)) {
        _applyGracefulDegradation(error);
      } else {
        _showMinimalError(error);
      }
    });
  }

  /// Handle permanent failures that require fallback UI
  void _handlePermanentFailure(String reason) {
    setState(() {
      _hasARError = true;
      _fallbackReason = reason;
    });
  }

  /// Handle permission failures with specific guidance
  void _handlePermissionFailure() {
    setState(() {
      _hasARError = true;
      _fallbackReason = 'Camera permission is required for AR';
    });

    // Show permission dialog after a delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _showPermissionDialog();
      }
    });
  }

  /// Handle initialization failures with retry option
  void _handleInitializationFailure() {
    setState(() {
      _hasARError = true;
      _fallbackReason = 'AR initialization failed';
    });
  }

  /// Handle temporary failures that might recover
  void _handleTemporaryFailure(String reason) {
    setState(() {
      _hasARError = true;
      _fallbackReason = reason;
    });

    // Schedule automatic retry for temporary failures
    _scheduleAutomaticRetry();
  }

  /// Handle session pause (usually temporary)
  void _handleSessionPause() {
    // Don't show fallback UI for session pause, just log it
    debugPrint('AR session paused - will attempt automatic resume');
  }

  /// Handle model loading failures
  void _handleModelLoadingFailure() {
    // Don't switch to fallback for model loading issues
    // Just show a temporary message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load 3D model. Retrying...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Handle network failures
  void _handleNetworkFailure() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network connection required for some AR features'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Handle generic failures
  void _handleGenericFailure(ARError error) {
    if (error.isRecoverable) {
      setState(() {
        _hasARError = true;
        _fallbackReason = error.userFriendlyMessage;
      });
    }
  }

  /// Show fallback UI for permanent failures
  void _showFallbackUI(ARError error) {
    final message = _fallbackStrategy.getFallbackMessage(error);
    setState(() {
      _hasARError = true;
      _fallbackReason = message;
    });

    // Show permission dialog for permission errors
    if (error.type == ARErrorType.permissions) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _showPermissionDialog();
        }
      });
    }
  }

  /// Schedule automatic recovery
  void _scheduleAutoRecovery(ARError error) {
    final message = _fallbackStrategy.getFallbackMessage(error);
    setState(() {
      _hasARError = true;
      _fallbackReason = message;
    });

    // Use fallback strategy to schedule recovery
    _fallbackStrategy.scheduleAutoRecovery(error, () async {
      if (!mounted) return false;

      try {
        // Clear error state
        setState(() {
          _hasARError = false;
          _fallbackReason = '';
        });

        // Attempt to reinitialize AR
        return await _arManager.initialize();
      } catch (e) {
        debugPrint('Auto-recovery failed: $e');
        return false;
      }
    });
  }

  /// Apply graceful degradation
  void _applyGracefulDegradation(ARError error) {
    final message = _fallbackStrategy.getFallbackMessage(error);

    // Show temporary notification but don't switch to fallback UI
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // For session pause, attempt automatic resume
    if (error.type == ARErrorType.sessionPause) {
      Future.delayed(const Duration(seconds: 5), () async {
        if (mounted) {
          try {
            await _arManager.resumeSession();
          } catch (e) {
            debugPrint('Failed to resume AR session: $e');
          }
        }
      });
    }
  }

  /// Show minimal error notification
  void _showMinimalError(ARError error) {
    final config = _fallbackStrategy.getFallbackConfig(error.type);

    if (config.showUserNotification && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.userFriendlyMessage),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.grey[700],
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // This is handled by the ResourceManager now, but we keep this for reference
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('ARViewWrapper: App resumed');
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        debugPrint('ARViewWrapper: App paused/inactive/detached/hidden');
        break;
    }
  }

  /// Check if AR is available and enabled
  Future<void> _checkARAvailability() async {
    setState(() {
      _isLoading = true;
      _hasARError = false;
    });

    try {
      // Initialize settings service
      final settingsService = SettingsService();
      if (!settingsService.isInitialized) {
        await settingsService.initialize();
      }

      // Check if AR is enabled in settings
      final isAREnabled = settingsService.isAREnabled;

      // Check if AR is available on the device
      final isARAvailable = await _arManager.initialize();

      // Get debug info setting
      final showDebugInfo = settingsService.showDebugInfo;

      // Initialize resource manager
      await _resourceManager.initialize();

      // Determine fallback reason if AR is not available
      String fallbackReason = '';
      bool hasError = false;

      if (!isAREnabled) {
        fallbackReason = 'AR is disabled in settings';
        hasError = true;
      } else if (!isARAvailable) {
        fallbackReason = 'AR is not supported on this device';
        hasError = true;
      }

      setState(() {
        _isAREnabled = isAREnabled;
        _isARAvailable = isARAvailable;
        _showDebugInfo = showDebugInfo;
        _hasARError = hasError;
        _fallbackReason = fallbackReason;
        _isLoading = false;
      });
    } catch (e) {
      await _errorHandler.handleException(
        e is Exception ? e : Exception(e.toString()),
        type: ARErrorType.initialization,
        customMessage: 'Failed to check AR availability',
        buildContext: mounted ? context : null,
        showUserFeedback: false,
      );

      setState(() {
        _isAREnabled = false;
        _isARAvailable = false;
        _hasARError = true;
        _fallbackReason = 'Failed to initialize AR system';
        _isLoading = false;
      });
    }
  }

  /// Retry AR initialization
  Future<void> _retryARInitialization() async {
    if (_retryCount >= _maxRetries) {
      // Show message that max retries reached
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Maximum retry attempts reached. Please restart the app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _retryCount++;
    debugPrint(
        'Retrying AR initialization (attempt $_retryCount/$_maxRetries)');

    // Wait a bit before retrying
    await Future.delayed(const Duration(seconds: 2));

    // Reset AR manager
    _arManager.dispose();

    // Try to initialize again
    await _checkARAvailability();

    // If still failed, show appropriate message
    if (_hasARError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Retry $_retryCount failed. ${_maxRetries - _retryCount} attempts remaining.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRetryTimer?.cancel();
    _fallbackStrategy.cancelAllRecoveryTimers();
    // Error listener cleanup is handled automatically
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Initializing AR...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Check if we should use fallback UI
    if (_hasARError || !_isARAvailable || !_isAREnabled) {
      return ARFallbackUI(
        recognitions: widget.recognitions,
        onModelInteraction: widget.onModelInteraction,
        fallbackReason: _fallbackReason,
        showRetry: _canRetry(),
        onRetry: _canRetry() ? _retryARInitialization : null,
      );
    }

    // Filter recognitions based on confidence threshold
    final filteredRecognitions = widget.recognitions.where((recognition) {
      final confidence = recognition['confidence'] as double? ?? 0.0;
      return confidence >= 0.65;
    }).toList();

    // If no high-confidence detections, show AR view with empty state
    if (filteredRecognitions.isEmpty && widget.recognitions.isNotEmpty) {
      // Still show AR view but with low confidence message
      return Stack(
        children: [
          ARView(
            recognitions: [],
            onModelInteraction: widget.onModelInteraction,
            showDebugInfo: _showDebugInfo,
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search,
                    color: Colors.white70,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Looking for objects...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detection confidence too low (${(widget.recognitions.first['confidence'] as double? ?? 0.0 * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Show full AR experience
    return ARView(
      recognitions: filteredRecognitions,
      onModelInteraction: widget.onModelInteraction,
      showDebugInfo: _showDebugInfo,
    );
  }

  /// Show permission dialog to guide user
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.blue),
              SizedBox(width: 8),
              Text('Camera Permission Required'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AR features require camera access to work properly.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'Please grant camera permission in your device settings to enable AR mode.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Could open app settings here if permission_handler is available
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue without AR'),
            ),
          ],
        );
      },
    );
  }

  /// Schedule automatic retry for temporary failures
  void _scheduleAutomaticRetry() {
    // Cancel any existing timer
    _autoRetryTimer?.cancel();

    // Schedule retry based on failure type
    Duration retryDelay = const Duration(seconds: 30);

    if (_fallbackReason.contains('overheating')) {
      retryDelay = const Duration(minutes: 2);
    } else if (_fallbackReason.contains('memory')) {
      retryDelay = const Duration(seconds: 45);
    }

    _autoRetryTimer = Timer(retryDelay, () {
      if (mounted && _hasARError) {
        debugPrint('Attempting automatic AR recovery...');
        _checkARAvailability();
      }
    });
  }

  /// Check if retry is possible
  bool _canRetry() {
    return _retryCount < _maxRetries &&
        (_fallbackReason.contains('initialization') ||
            _fallbackReason.contains('failed') ||
            _fallbackReason.contains('overheating') ||
            _fallbackReason.contains('memory'));
  }
}
