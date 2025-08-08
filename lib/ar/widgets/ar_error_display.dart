import 'package:flutter/material.dart';
import '../utils/ar_error_handler.dart';

/// Widget for displaying AR errors in a user-friendly way
class ARErrorDisplay extends StatelessWidget {
  final ARError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showDetails;
  final EdgeInsets? padding;

  const ARErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showDetails = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Icon(
                _getErrorIcon(),
                color: _getIconColor(),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getErrorTitle(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getTextColor(),
                      ),
                    ),
                    Text(
                      error.userFriendlyMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: _getTextColor().withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    color: _getTextColor().withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
            ],
          ),

          // Recovery suggestion
          if (error.recoverySuggestion.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getIconColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: _getIconColor(),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error.recoverySuggestion,
                      style: TextStyle(
                        fontSize: 13,
                        color: _getTextColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error details (if requested)
          if (showDetails && error.details != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text(
                'Technical Details',
                style: TextStyle(fontSize: 14),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error Type: ${error.type}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Timestamp: ${error.timestamp}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (error.details != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Details: ${error.details}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      if (error.context != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Context: ${error.context}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],

          // Action buttons
          if (error.isRecoverable && onRetry != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: _getIconColor(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Get error title based on type
  String _getErrorTitle() {
    switch (error.type) {
      case ARErrorType.initialization:
        return 'AR Initialization Failed';
      case ARErrorType.sessionStart:
        return 'AR Session Error';
      case ARErrorType.deviceCompatibility:
        return 'Device Not Compatible';
      case ARErrorType.permissions:
        return 'Permission Required';
      case ARErrorType.modelLoading:
        return 'Model Loading Error';
      case ARErrorType.thermalThrottling:
        return 'Device Overheating';
      case ARErrorType.memoryPressure:
        return 'Low Memory';
      case ARErrorType.networkConnection:
        return 'Network Error';
      default:
        return 'AR Error';
    }
  }

  /// Get appropriate icon for error type
  IconData _getErrorIcon() {
    switch (error.type) {
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
  Color _getIconColor() {
    switch (error.type) {
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

  /// Get background color based on error severity
  Color _getBackgroundColor() {
    final baseColor = _getIconColor();
    return baseColor.withValues(alpha: 0.05);
  }

  /// Get border color based on error severity
  Color _getBorderColor() {
    final baseColor = _getIconColor();
    return baseColor.withValues(alpha: 0.2);
  }

  /// Get text color
  Color _getTextColor() {
    return Colors.black87;
  }
}

/// Snackbar variant of error display
class ARErrorSnackBar extends SnackBar {
  ARErrorSnackBar({
    super.key,
    required ARError error,
    VoidCallback? onRetry,
  }) : super(
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
                  onPressed: onRetry,
                )
              : null,
        );

  static IconData _getErrorIcon(ARErrorType type) {
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

  static Color _getErrorColor(ARErrorType type) {
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
}

/// Dialog variant of error display
class ARErrorDialog extends StatelessWidget {
  final ARError error;
  final VoidCallback? onRetry;

  const ARErrorDialog({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getErrorIcon(),
            color: _getErrorColor(),
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
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  IconData _getErrorIcon() {
    return ARErrorSnackBar._getErrorIcon(error.type);
  }

  Color _getErrorColor() {
    return ARErrorSnackBar._getErrorColor(error.type);
  }
}
