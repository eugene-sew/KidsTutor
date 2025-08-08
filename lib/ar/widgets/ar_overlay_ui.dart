import 'package:flutter/material.dart';
import '../utils/ar_manager.dart';
import '../utils/thermal_manager.dart' show ThermalManager, ThermalState;
import '../models/ar_model.dart';

/// A class containing UI components that overlay the AR view
class AROverlayUI {
  /// Build a connection line between a detected object and its 3D model
  static Widget buildConnectionLine({
    required Offset objectPosition,
    required Offset modelPosition,
    required double confidence,
    Color color = Colors.blue,
  }) {
    return CustomPaint(
      size: Size.infinite,
      painter: ConnectionLinePainter(
        start: objectPosition,
        end: modelPosition,
        confidence: confidence,
        color: color,
      ),
    );
  }

  /// Build a loading indicator for AR initialization or model loading
  static Widget buildLoadingIndicator({String? message}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Build an error indicator for AR failures
  static Widget buildErrorIndicator({
    required String message,
    VoidCallback? onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.7), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build a thermal warning indicator when device is overheating
  static Widget buildThermalWarning({
    required ThermalState thermalState,
    required double temperature,
  }) {
    Color color;
    String message;
    IconData icon;

    switch (thermalState) {
      case ThermalState.elevated:
        color = Colors.orange;
        message =
            'Device is getting warm (${temperature.toStringAsFixed(1)}°C)';
        icon = Icons.thermostat;
        break;
      case ThermalState.critical:
        color = Colors.red;
        message = 'Device is overheating (${temperature.toStringAsFixed(1)}°C)';
        icon = Icons.warning_amber_rounded;
        break;
      default:
        return const SizedBox.shrink(); // No warning for normal temperature
    }

    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a model placement indicator to show where a model will be placed
  static Widget buildModelPlacementIndicator({
    required Offset position,
    double size = 60,
    Color color = Colors.blue,
  }) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          color: color.withOpacity(0.2),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            color: color,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  /// Build an object detection highlight to show detected objects
  static Widget buildObjectDetectionHighlight({
    required Rect boundingBox,
    required String label,
    required double confidence,
    Color color = Colors.green,
  }) {
    return Positioned(
      left: boundingBox.left,
      top: boundingBox.top,
      width: boundingBox.width,
      height: boundingBox.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: color,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                '$label (${(confidence * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a model info tooltip that appears when a model is selected
  static Widget buildModelInfoTooltip({
    required ARModel model,
    required Offset position,
    VoidCallback? onClose,
  }) {
    return Positioned(
      left: position.dx,
      top: position.dy - 120, // Position above the model
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  model.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (model.pronunciation.isNotEmpty) ...[
              Text(
                'Pronunciation: ${model.pronunciation}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (model.funFact != null) ...[
              const SizedBox(height: 4),
              Text(
                model.funFact!,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a status bar with AR session information
  static Widget buildStatusBar({
    required ARManager arManager,
    required bool isAREnabled,
  }) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        color: Colors.black.withOpacity(0.7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  arManager.isSessionActive
                      ? (arManager.isSessionPaused
                          ? Icons.pause
                          : Icons.view_in_ar)
                      : Icons.cancel,
                  color: arManager.isSessionActive
                      ? (arManager.isSessionPaused
                          ? Colors.orange
                          : Colors.green)
                      : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  arManager.isSessionActive
                      ? (arManager.isSessionPaused ? 'AR Paused' : 'AR Active')
                      : 'AR Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Text(
              'FPS: ${arManager.currentFPS.toStringAsFixed(1)}',
              style: TextStyle(
                color: arManager.currentFPS > 24 ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
            Text(
              'Models: ${arManager.activeNodes.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for drawing a connection line between a detected object and its 3D model
class ConnectionLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double confidence;
  final Color color;

  ConnectionLinePainter({
    required this.start,
    required this.end,
    required this.confidence,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(confidence)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw dashed line
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Create a curved path
    final controlPoint1 = Offset(
      start.dx + (end.dx - start.dx) / 4,
      start.dy + (end.dy - start.dy) / 2,
    );
    final controlPoint2 = Offset(
      start.dx + (end.dx - start.dx) * 3 / 4,
      start.dy + (end.dy - start.dy) / 2,
    );

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      end.dx,
      end.dy,
    );

    // Draw the path with dash effect
    final dashPath = Path();
    const dashWidth = 6.0;
    const dashSpace = 3.0;
    double distance = 0.0;
    final pathMetrics = path.computeMetrics().first;

    while (distance < pathMetrics.length) {
      final extractPath = pathMetrics.extractPath(
        distance,
        distance + dashWidth,
      );
      dashPath.addPath(extractPath, Offset.zero);
      distance += dashWidth + dashSpace;
    }

    canvas.drawPath(dashPath, paint);

    // Draw circles at start and end points
    final circlePaint = Paint()
      ..color = color.withOpacity(confidence)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(start, 4, circlePaint);
    canvas.drawCircle(end, 4, circlePaint);
  }

  @override
  bool shouldRepaint(ConnectionLinePainter oldDelegate) {
    return start != oldDelegate.start ||
        end != oldDelegate.end ||
        confidence != oldDelegate.confidence ||
        color != oldDelegate.color;
  }
}
