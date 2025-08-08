import 'package:flutter/material.dart';
import '../utils/ar_manager.dart';
import '../utils/thermal_manager.dart';
import '../models/ar_model.dart';
import 'ar_overlay_ui.dart';

/// A controller widget that manages AR overlay UI components
class AROverlayController extends StatefulWidget {
  /// List of object recognitions from the ML model
  final List<Map<String, dynamic>> recognitions;

  /// Whether the AR session is initializing
  final bool isInitializing;

  /// Whether there was an error initializing AR
  final bool hasError;

  /// Error message if there was an error
  final String? errorMessage;

  /// Callback when retry is pressed after an error
  final VoidCallback? onRetry;

  /// Whether to show debug information
  final bool showDebugInfo;

  /// Constructor
  const AROverlayController({
    Key? key,
    required this.recognitions,
    this.isInitializing = false,
    this.hasError = false,
    this.errorMessage,
    this.onRetry,
    this.showDebugInfo = false,
  }) : super(key: key);

  @override
  AROverlayControllerState createState() => AROverlayControllerState();
}

class AROverlayControllerState extends State<AROverlayController> {
  // AR Manager instance
  final ARManager _arManager = ARManager();

  // Thermal Manager instance
  final ThermalManager _thermalManager = ThermalManager();


  // Currently selected model
  ARModel? _selectedModel;

  // Position of the selected model
  Offset? _selectedModelPosition;

  // Map of object positions (for connection lines)
  final Map<String, Offset> _objectPositions = {};

  // Map of model positions (for connection lines)
  final Map<String, Offset> _modelPositions = {};

  @override
  void initState() {
    super.initState();
    _updateObjectPositions();
  }

  @override
  void didUpdateWidget(AROverlayController oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update object positions when recognitions change
    if (widget.recognitions != oldWidget.recognitions) {
      _updateObjectPositions();
    }
  }

  /// Update the positions of detected objects
  void _updateObjectPositions() {
    final screenSize = MediaQuery.of(context).size;

    for (final recognition in widget.recognitions) {
      final label = recognition['label'] as String? ?? '';
      final confidence = recognition['confidence'] as double? ?? 0.0;

      if (label.isNotEmpty && confidence > 0.65) {
        // Extract letter from label (e.g. "1 A" -> "A")
        final letterLabel = _extractLetterFromLabel(label);

        if (letterLabel.isNotEmpty) {
          // Get position from recognition if available
          if (recognition['position'] != null) {
            final posX = (recognition['position']['x'] as double?) ?? 0.5;
            final posY = (recognition['position']['y'] as double?) ?? 0.5;

            // Convert normalized position (0-1) to screen position
            _objectPositions[letterLabel] = Offset(
              posX * screenSize.width,
              posY * screenSize.height,
            );

            // If we don't have a model position yet, initialize it
            if (!_modelPositions.containsKey(letterLabel)) {
              // Position the model below the detected object
              _modelPositions[letterLabel] = Offset(
                posX * screenSize.width,
                (posY * screenSize.height) + 200, // 200px below the object
              );
            }
          } else {
            // Fallback to simulated positions if no position data
            _objectPositions[letterLabel] = Offset(
              100 + (letterLabel.codeUnitAt(0) - 65) * 10,
              200,
            );

            // Simulate a position for the 3D model if not already set
            if (!_modelPositions.containsKey(letterLabel)) {
              _modelPositions[letterLabel] = Offset(
                100 + (letterLabel.codeUnitAt(0) - 65) * 10,
                400,
              );
            }
          }
        }
      }
    }
  }

  /// Extract the letter from a label string (e.g. "1 A" -> "A")
  String _extractLetterFromLabel(String label) {
    final parts = label.split(' ');
    if (parts.length > 1) {
      return parts[1];
    }
    return '';
  }

  /// Select a model to show its info tooltip
  void selectModel(ARModel model, Offset position) {
    setState(() {
      _selectedModel = model;
      _selectedModelPosition = position;

      // Add to model positions map for connection lines
      final letterLabel = model.name.substring(0, 1).toUpperCase();
      _modelPositions[letterLabel] = position;
    });
  }

  /// Update the position of an existing model
  void updateModelPosition(ARModel model, Offset position) {
    setState(() {
      // Update the selected model position if it's the same model
      if (_selectedModel != null && _selectedModel!.id == model.id) {
        _selectedModelPosition = position;
      }

      // Update the model position in the map
      final letterLabel = model.name.substring(0, 1).toUpperCase();
      _modelPositions[letterLabel] = position;
    });
  }

  /// Clear the selected model
  void clearSelectedModel() {
    setState(() {
      _selectedModel = null;
      _selectedModelPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Connection lines between objects and models
        ..._buildConnectionLines(),

        // Loading indicator
        if (widget.isInitializing)
          Center(
            child: AROverlayUI.buildLoadingIndicator(
              message: 'Initializing AR...',
            ),
          ),

        // Error indicator
        if (widget.hasError)
          Center(
            child: AROverlayUI.buildErrorIndicator(
              message: widget.errorMessage ?? 'Failed to initialize AR',
              onRetry: widget.onRetry,
            ),
          ),

        // Thermal warning
        AROverlayUI.buildThermalWarning(
          thermalState: _thermalManager.currentThermalState,
          temperature: _thermalManager.currentTemperature,
        ),

        // Status bar (only in debug mode)
        if (widget.showDebugInfo)
          AROverlayUI.buildStatusBar(
            arManager: _arManager,
            isAREnabled: true,
          ),

        // Selected model info tooltip
        if (_selectedModel != null && _selectedModelPosition != null)
          AROverlayUI.buildModelInfoTooltip(
            model: _selectedModel!,
            position: _selectedModelPosition!,
            onClose: clearSelectedModel,
          ),

        // Object detection highlights
        ..._buildObjectDetectionHighlights(),
      ],
    );
  }

  /// Build connection lines between detected objects and their 3D models
  List<Widget> _buildConnectionLines() {
    final lines = <Widget>[];

    // Only draw lines for objects that have both positions
    for (final entry in _objectPositions.entries) {
      final letterLabel = entry.key;
      final objectPosition = entry.value;

      if (_modelPositions.containsKey(letterLabel)) {
        final modelPosition = _modelPositions[letterLabel]!;

        // Find the confidence for this letter
        double confidence = 0.8; // Default confidence
        for (final recognition in widget.recognitions) {
          final label = recognition['label'] as String? ?? '';
          if (label.contains(letterLabel)) {
            confidence = recognition['confidence'] as double? ?? 0.8;
            break;
          }
        }

        lines.add(
          AROverlayUI.buildConnectionLine(
            objectPosition: objectPosition,
            modelPosition: modelPosition,
            confidence: confidence,
            color: Colors.blue,
          ),
        );
      }
    }

    return lines;
  }

  /// Build highlights for detected objects
  List<Widget> _buildObjectDetectionHighlights() {
    final highlights = <Widget>[];

    // In a real implementation, this would use the actual bounding boxes
    // For this example, we'll use simulated bounding boxes
    for (final recognition in widget.recognitions) {
      final label = recognition['label'] as String? ?? '';
      final confidence = recognition['confidence'] as double? ?? 0.0;

      if (label.isNotEmpty && confidence > 0.65) {
        // Extract letter from label
        final letterLabel = _extractLetterFromLabel(label);

        if (letterLabel.isNotEmpty &&
            _objectPositions.containsKey(letterLabel)) {
          final position = _objectPositions[letterLabel]!;

          // Create a simulated bounding box
          final boundingBox = Rect.fromCenter(
            center: position,
            width: 80,
            height: 80,
          );

          highlights.add(
            AROverlayUI.buildObjectDetectionHighlight(
              boundingBox: boundingBox,
              label: letterLabel,
              confidence: confidence,
              color: Colors.green,
            ),
          );
        }
      }
    }

    return highlights;
  }
}
