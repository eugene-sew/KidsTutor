import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../utils/ar_manager.dart';
import '../utils/ar_error_handler.dart';
import '../utils/model_manager.dart';
import '../utils/resource_manager.dart';
import '../utils/thermal_manager.dart' as thermal;
import '../models/ar_model_mapping.dart';
import '../models/ar_model.dart';
import 'ar_overlay_controller.dart';
import 'ar_overlay_ui.dart';

/// A widget that renders an AR scene with 3D models
class ARView extends StatefulWidget {
  /// List of object recognitions from the ML model
  final List<Map<String, dynamic>> recognitions;

  /// Callback when a model is interacted with
  final Function(ARModel model)? onModelInteraction;

  /// Whether to show debug info
  final bool showDebugInfo;

  /// Constructor
  const ARView({
    Key? key,
    required this.recognitions,
    this.onModelInteraction,
    this.showDebugInfo = false,
  }) : super(key: key);

  @override
  _ARViewState createState() => _ARViewState();
}

class _ARViewState extends State<ARView> with TickerProviderStateMixin {
  // Currently displayed models
  final Map<String, ARModel> _displayedModels = {};

  // AR nodes in the scene
  final Map<String, ARNode> _arNodes = {};

  // Model manager instance
  final ModelManager _modelManager = ModelManager();

  // AR manager instance
  final ARManager _arManager = ARManager();

  // Error handler
  final ARErrorHandler _errorHandler = ARErrorHandler();

  // Debug message
  String _debugMessage = 'Initializing AR...';

  // Light intensity for 3D models
  double _lightIntensity = 1.0;

  // Environment lighting
  String _environmentLighting = 'neutral';

  // AR overlay controller key
  final GlobalKey<AROverlayControllerState> _overlayControllerKey =
      GlobalKey<AROverlayControllerState>();

  // AR initialization state
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;

  // Currently selected model
  String? _selectedModelId;

  // Visual feedback animation controller
  late AnimationController _selectionAnimationController;
  late Animation<double> _selectionAnimation;

  // Gesture control variables
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  double _currentRotationAngle = 0.0;
  double _baseRotationAngle = 0.0;

  // Animation controllers for smooth transformations
  late AnimationController _scaleAnimationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _rotationAnimationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAR();
    _updateModelsFromRecognitions();

    // Initialize selection animation controller
    _selectionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _selectionAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _selectionAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _selectionAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _selectionAnimationController.reverse();
      }
    });

    // Initialize scale animation controller
    _scaleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Initialize rotation animation controller
    _rotationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _rotationAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Initialize AR components
  Future<void> _initializeAR() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await _arManager.initialize();
      await _arManager.startSession();
      await _modelManager.preloadCommonModels();

      // Initialize resource manager
      await ResourceManager().initialize();

      setState(() {
        _debugMessage = 'AR initialized, waiting for objects...';
        _isInitializing = false;
      });
    } catch (e) {
      await _errorHandler.handleException(
        e is Exception ? e : Exception(e.toString()),
        type: ARErrorType.initialization,
        customMessage: 'Failed to initialize AR components',
        buildContext: context,
        onRetry: () async {
          await _retryInitialization();
          return true;
        },
      );

      setState(() {
        _debugMessage = 'AR initialization failed: $e';
        _isInitializing = false;
        _hasError = true;
        _errorMessage = 'Failed to initialize AR: $e';
      });
    }
  }

  @override
  void didUpdateWidget(ARView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update models when recognitions change
    if (widget.recognitions != oldWidget.recognitions) {
      _updateModelsFromRecognitions();
    }
  }

  /// Update the displayed models based on recognitions
  Future<void> _updateModelsFromRecognitions() async {
    if (widget.recognitions.isEmpty) return;

    // Get the top recognition
    final topRecognition = widget.recognitions.first;
    final letterLabel = _extractLetterFromLabel(topRecognition['label'] ?? '');
    final confidence = topRecognition['confidence'] ?? 0.0;

    // Get the recognition position if available
    final Offset? recognitionPosition = topRecognition['position'] != null
        ? Offset(
            (topRecognition['position']['x'] as double?) ?? 0.5,
            (topRecognition['position']['y'] as double?) ?? 0.5,
          )
        : null;

    // Only proceed if we have a letter and confidence is high enough
    if (letterLabel.isNotEmpty && confidence > 0.65) {
      // Get the model for this letter
      final model = ARModelMapping().getModelForLetter(letterLabel);
      if (model != null) {
        if (!_displayedModels.containsKey(letterLabel)) {
          // Add model to displayed models
          setState(() {
            _displayedModels[letterLabel] = model;
            _debugMessage = 'Displaying model for $letterLabel: ${model.name}';
          });

          // Place the 3D model in AR space
          await _placeModelInARSpace(letterLabel, model, recognitionPosition);
        } else if (recognitionPosition != null) {
          // Update position of existing model based on new detection
          await _updateModelPosition(letterLabel, recognitionPosition);
        }
      }
    }
  }

  /// Place a 3D model in AR space with enhanced rendering properties
  Future<void> _placeModelInARSpace(String letterLabel, ARModel model,
      [Offset? recognitionPosition]) async {
    try {
      // Calculate position based on the recognition position or center of the screen
      Vector3 position;

      if (recognitionPosition != null) {
        // Convert screen position to AR space position
        // Map from (0,0)-(1,1) to AR space coordinates
        final screenSize = MediaQuery.of(context).size;
        final normalizedX =
            (recognitionPosition.dx * 2) - 1.0; // Map 0-1 to -1 to 1
        final normalizedY = -((recognitionPosition.dy * 2) -
            1.0); // Flip Y and map 0-1 to -1 to 1

        // Use normalized coordinates to position in AR space
        // X: left-right, Y: up-down, Z: depth
        position = Vector3(
          normalizedX * 1.5, // Scale for wider horizontal movement
          normalizedY * 0.5 -
              0.3, // Scale for vertical movement and offset down a bit
          -2.0, // Fixed distance from camera
        );

        debugPrint(
            'Placing model at position based on detection: $position from screen pos: $recognitionPosition');
      } else {
        // Default position in front of camera
        position = Vector3(0, -0.5, -2.0);
        debugPrint('Placing model at default position: $position');
      }

      // Get resource manager to check performance status
      final resourceManager = ResourceManager();

      // Get the model node from the model manager with enhanced rendering properties and optimization
      final node = await _modelManager.getOptimizedModel(
        model.id,
        model,
      );

      if (node != null) {
        // Add the node to the AR scene with enhanced rendering properties
        final arNode = await _arManager.addModelToScene(
          id: letterLabel,
          modelPath: node.modelPath,
          position: position,
          scale: model.scale,
          rotation: model.rotation,
          shadowIntensity: model.shadowIntensity,
          shadowSoftness: model.shadowSoftness,
          exposure: model.exposure,
          environmentLighting: model.environmentLighting,
          colorTint: model.colorTint,
          animationName: model.animationName,
          autoRotate: model.autoRotate,
          autoRotateSpeed: model.autoRotateSpeed,
        );

        if (arNode != null) {
          setState(() {
            _arNodes[letterLabel] = arNode;
            _debugMessage =
                'Placed model for $letterLabel in AR space with enhanced rendering';

            // Update lighting environment based on model settings
            _environmentLighting = model.environmentLighting;
            _lightIntensity = model.exposure;

            // Update the overlay controller with the new model
            if (_overlayControllerKey.currentState != null) {
              // Use the actual recognition position if available, otherwise use center
              final screenPos = recognitionPosition != null
                  ? Offset(
                      recognitionPosition.dx *
                          MediaQuery.of(context).size.width,
                      recognitionPosition.dy *
                          MediaQuery.of(context).size.height)
                  : Offset(MediaQuery.of(context).size.width / 2,
                      MediaQuery.of(context).size.height / 2);

              _overlayControllerKey.currentState!.selectModel(
                model,
                screenPos,
              );
            }
          });
        }
      }
    } catch (e) {
      await _errorHandler.handleException(
        e is Exception ? e : Exception(e.toString()),
        type: ARErrorType.modelPlacement,
        customMessage: 'Failed to place model in AR space',
        context: {
          'letterLabel': letterLabel,
          'modelName': model.name,
          'recognitionPosition': recognitionPosition?.toString(),
        },
        buildContext: context,
        showUserFeedback: false,
      );
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

  /// Update the position of an existing model based on new detection
  Future<void> _updateModelPosition(
      String letterLabel, Offset recognitionPosition) async {
    if (!_arNodes.containsKey(letterLabel)) return;

    try {
      final screenSize = MediaQuery.of(context).size;
      final normalizedX =
          (recognitionPosition.dx * 2) - 1.0; // Map 0-1 to -1 to 1
      final normalizedY = -((recognitionPosition.dy * 2) -
          1.0); // Flip Y and map 0-1 to -1 to 1

      // Use normalized coordinates to position in AR space
      final position = Vector3(
        normalizedX * 1.5, // Scale for wider horizontal movement
        normalizedY * 0.5 -
            0.3, // Scale for vertical movement and offset down a bit
        -2.0, // Fixed distance from camera
      );

      // Get the existing node
      final existingNode = _arNodes[letterLabel]!;
      final model = _displayedModels[letterLabel]!;

      // Update the node position
      final updatedNode = await _arManager.addModelToScene(
        id: letterLabel,
        modelPath: existingNode.modelPath,
        position: position,
        scale: model.scale,
        rotation: model.rotation,
        shadowIntensity: existingNode.shadowIntensity,
        shadowSoftness: existingNode.shadowSoftness,
        exposure: existingNode.exposure,
        environmentLighting: existingNode.environmentLighting,
        colorTint: existingNode.colorTint,
        animationName: existingNode.animationName,
        autoRotate: existingNode.autoRotate,
        autoRotateSpeed: existingNode.autoRotateSpeed,
      );

      if (updatedNode != null) {
        setState(() {
          _arNodes[letterLabel] = updatedNode;
          _debugMessage =
              'Updated position for model $letterLabel based on detection';

          // Update the overlay controller with the new position
          if (_overlayControllerKey.currentState != null) {
            final screenPos = Offset(recognitionPosition.dx * screenSize.width,
                recognitionPosition.dy * screenSize.height);

            _overlayControllerKey.currentState!.updateModelPosition(
              _displayedModels[letterLabel]!,
              screenPos,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error updating model position: $e');
    }
  }

  @override
  void dispose() {
    // Clean up AR resources
    for (final letter in _arNodes.keys) {
      _arManager.removeNode(letter);
    }

    // Stop AR session
    _arManager.stopSession();

    // Dispose animation controllers
    _selectionAnimationController.dispose();
    _scaleAnimationController.dispose();
    _rotationAnimationController.dispose();

    super.dispose();
  }

  /// Handle tap on the AR view
  void _handleTap(TapUpDetails details) async {
    if (_displayedModels.isEmpty) return;

    final screenSize = MediaQuery.of(context).size;
    final hitModelId =
        await _arManager.performHitTest(details.localPosition, screenSize);

    setState(() {
      _selectedModelId = hitModelId;
      _debugMessage = hitModelId != null
          ? 'Selected model: $hitModelId'
          : 'No model selected';
    });

    if (hitModelId != null) {
      // Play selection animation
      _selectionAnimationController.forward();

      // Show model information
      _showModelInfo(hitModelId);

      // Call the interaction callback if provided
      if (widget.onModelInteraction != null &&
          _displayedModels.containsKey(hitModelId)) {
        widget.onModelInteraction!(_displayedModels[hitModelId]!);
      }
    }
  }

  /// Show information about the selected model
  void _showModelInfo(String modelId) {
    if (!_displayedModels.containsKey(modelId)) return;

    final model = _displayedModels[modelId]!;

    // Show a snackbar with model information
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              model.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (model.pronunciation.isNotEmpty)
              Text('Pronunciation: ${model.pronunciation}'),
            if (model.funFact != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(model.funFact!),
              ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Close',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Handle scale gesture for pinch-to-zoom
  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
    _baseRotationAngle = _currentRotationAngle;
  }

  /// Handle scale update for pinch-to-zoom and rotation
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_selectedModelId == null ||
        !_displayedModels.containsKey(_selectedModelId)) return;

    // Calculate new scale
    final newScale = (_baseScale * details.scale).clamp(0.5, 3.0);

    // Calculate new rotation angle
    final newRotationAngle = _baseRotationAngle + details.rotation;

    // Only update if there's a significant change
    if ((newScale - _currentScale).abs() > 0.01 ||
        (newRotationAngle - _currentRotationAngle).abs() > 0.01) {
      setState(() {
        _currentScale = newScale;
        _currentRotationAngle = newRotationAngle;
        _debugMessage =
            'Scale: ${_currentScale.toStringAsFixed(2)}, Rotation: ${(_currentRotationAngle * 180 / 3.14159).toStringAsFixed(1)}°';
      });

      // Apply transformation to the model
      _applyModelTransformation(
          _selectedModelId!, _currentScale, _currentRotationAngle);
    }
  }

  /// Handle scale end for smooth animation
  void _handleScaleEnd(ScaleEndDetails details) {
    if (_selectedModelId == null) return;

    // Animate to final scale and rotation for smooth finish
    _scaleAnimationController.stop();
    _scaleAnimation = Tween<double>(
      begin: _currentScale,
      end: _currentScale.roundToDouble().clamp(0.5, 3.0),
    ).animate(_scaleAnimationController);

    _scaleAnimationController.addListener(() {
      setState(() {
        _currentScale = _scaleAnimation.value;
        _applyModelTransformation(
            _selectedModelId!, _currentScale, _currentRotationAngle);
      });
    });

    _scaleAnimationController.forward(from: 0.0);
  }

  /// Apply transformation to the 3D model
  void _applyModelTransformation(
      String modelId, double scale, double rotationAngle) {
    if (!_arNodes.containsKey(modelId)) return;

    final node = _arNodes[modelId]!;
    final model = _displayedModels[modelId]!;

    // In a real implementation, we would update the actual 3D model transformation
    // For our simplified implementation, we'll just update the debug message
    _debugMessage =
        'Model $modelId transformed: Scale=${scale.toStringAsFixed(2)}, Rotation=${(rotationAngle * 180 / 3.14159).toStringAsFixed(1)}°';

    // Update the model in the AR scene with new scale and rotation
    _arManager.addModelToScene(
      id: modelId,
      modelPath: node.modelPath,
      position: node.position,
      scale: model.scale * scale,
      rotation: Vector3(0, rotationAngle, 0),
      shadowIntensity: node.shadowIntensity,
      shadowSoftness: node.shadowSoftness,
      exposure: node.exposure,
      environmentLighting: node.environmentLighting,
      colorTint: node.colorTint,
      animationName: node.animationName,
      autoRotate: node.autoRotate,
      autoRotateSpeed: node.autoRotateSpeed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTap,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      child: Stack(
        children: [
          // Background
          Container(
            color: Colors.black87,
          ),

          // 3D model viewer
          if (_displayedModels.isNotEmpty) _buildModelViewer(),

          // Debug info overlay
          if (widget.showDebugInfo) _buildDebugOverlay(),

          // Empty state message
          if (_displayedModels.isEmpty && !_isInitializing && !_hasError)
            _buildEmptyState(),

          // AR overlay with visual indicators, loading state, and error handling
          AROverlayController(
            key: _overlayControllerKey,
            recognitions: widget.recognitions,
            isInitializing: _isInitializing,
            hasError: _hasError,
            errorMessage: _errorMessage,
            onRetry: _retryInitialization,
            showDebugInfo: widget.showDebugInfo,
          ),

          // Selection indicator
          if (_selectedModelId != null &&
              _displayedModels.containsKey(_selectedModelId))
            _buildSelectionIndicator(),
        ],
      ),
    );
  }

  /// Build a visual indicator for the selected model
  Widget _buildSelectionIndicator() {
    // Get the first model to display (in a real app, we would use the selected model)
    final model = _displayedModels[_selectedModelId]!;

    return Center(
      child: AnimatedBuilder(
        animation: _selectionAnimation,
        builder: (context, child) {
          return Container(
            width: 100 * _selectionAnimation.value,
            height: 100 * _selectionAnimation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue,
                width: 3,
              ),
              color: Colors.blue.withOpacity(0.2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Colors.white,
                    size: 24 * _selectionAnimation.value,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * _selectionAnimation.value,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Retry AR initialization after an error
  Future<void> _retryInitialization() async {
    await _initializeAR();
  }

  /// Build the 3D model viewer with enhanced AR rendering
  Widget _buildModelViewer() {
    // Get the first model to display
    final entry = _displayedModels.entries.first;
    final letter = entry.key;
    final model = entry.value;

    // Check if this model is selected
    final isSelected = _selectedModelId == letter;

    return Stack(
      children: [
        // AR Scene - Full screen model viewer with enhanced rendering
        Positioned.fill(
          child: ModelViewer(
            backgroundColor: const Color.fromARGB(0, 0, 0, 0),
            src: model.modelPath,
            alt: 'A 3D model of ${model.name}',
            ar: true, // Enable AR mode
            arModes: const ['scene-viewer', 'webxr', 'quick-look'],
            autoRotate: isSelected
                ? true
                : model.autoRotate, // Always rotate when selected
            autoRotateDelay: 0,
            rotationPerSecond:
                '${isSelected ? model.autoRotateSpeed * 1.5 : model.autoRotateSpeed}deg',
            cameraControls: true,
            disableZoom: false,
            // Enhanced lighting and shadows
            shadowIntensity: isSelected
                ? model.shadowIntensity * 1.2
                : model.shadowIntensity,
            shadowSoftness: model.shadowSoftness,
            exposure: _lightIntensity,
            environmentImage: _getEnvironmentMap(),
            // Position and scale - apply current scale if this is the selected model
            scale: isSelected
                ? '${model.scale * _currentScale} ${model.scale * _currentScale} ${model.scale * _currentScale}'
                : '${model.scale} ${model.scale} ${model.scale}',
            // Improved camera settings
            fieldOfView: '30deg',
            minCameraOrbit: 'auto auto 5%',
            maxCameraOrbit: 'auto auto 100%',
            // Interaction hints
            interactionPrompt: InteractionPrompt.whenFocused,
            interactionPromptStyle: InteractionPromptStyle.basic,
            // Touch gestures
            touchAction: TouchAction.panY,
            // Loading and error handling
            loading: Loading.eager,
            reveal: Reveal.auto,
          ),
        ),

        // UI Overlay
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Model info card
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withAlpha(180)
                      : Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? Colors.blue.withAlpha(80)
                          : Colors.black.withAlpha(60),
                      blurRadius: isSelected ? 15 : 10,
                      spreadRadius: isSelected ? 3 : 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Letter and model name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Letter indicator
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isSelected ? 70 : 60,
                          height: isSelected ? 70 : 60,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withAlpha(220)
                                : Colors.blue.withAlpha(180),
                            borderRadius:
                                BorderRadius.circular(isSelected ? 16 : 12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withAlpha(100),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                color: isSelected ? Colors.blue : Colors.white,
                                fontSize: isSelected ? 42 : 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Model name and pronunciation
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  model.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSelected ? 28 : 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pronunciation: ${model.pronunciation}',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isSelected ? 16 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Fun fact if available
                    if (model.funFact != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(50)
                              : Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.amber,
                              size: isSelected ? 24 : 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                model.funFact!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSelected ? 16 : 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Additional information when selected
                    if (isSelected) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withAlpha(50),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tap on the model to interact:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInteractionTip(
                              icon: Icons.touch_app,
                              text: 'Tap to select and view details',
                            ),
                            _buildInteractionTip(
                              icon: Icons.rotate_right,
                              text: 'Drag to rotate the model',
                            ),
                            _buildInteractionTip(
                              icon: Icons.zoom_in,
                              text: 'Pinch to zoom in and out',
                            ),
                          ],
                        ),
                      ),

                      // Show current scale and rotation values
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Scale indicator
                            Column(
                              children: [
                                const Icon(
                                  Icons.zoom_in,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Scale: ${_currentScale.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),

                            // Rotation indicator
                            Column(
                              children: [
                                const Icon(
                                  Icons.rotate_right,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rotation: ${(_currentRotationAngle * 180 / 3.14159).toStringAsFixed(0)}°',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action buttons
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.info_outline,
                          label: 'Info',
                          onPressed: () {
                            if (widget.onModelInteraction != null) {
                              widget.onModelInteraction!(model);
                            }
                          },
                          isSelected: isSelected,
                        ),
                        _buildActionButton(
                          icon: Icons.lightbulb_outline,
                          label: 'Lighting',
                          onPressed: _cycleLighting,
                          isSelected: isSelected,
                        ),
                        _buildActionButton(
                          icon: Icons.close,
                          label: 'Remove',
                          onPressed: () {
                            _removeModel(letter);
                          },
                          isSelected: isSelected,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build an interaction tip item
  Widget _buildInteractionTip({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Remove a model from the scene
  void _removeModel(String letter) {
    // Remove from AR scene
    _arManager.removeNode(letter);

    // Remove from displayed models
    setState(() {
      _displayedModels.remove(letter);
      _arNodes.remove(letter);
    });
  }

  /// Cycle through lighting options
  void _cycleLighting() {
    setState(() {
      // Cycle through environment lighting options
      switch (_environmentLighting) {
        case 'neutral':
          _environmentLighting = 'sunset';
          _lightIntensity = 0.8;
          break;
        case 'sunset':
          _environmentLighting = 'night';
          _lightIntensity = 0.5;
          break;
        case 'night':
          _environmentLighting = 'bright';
          _lightIntensity = 1.5;
          break;
        case 'bright':
        default:
          _environmentLighting = 'neutral';
          _lightIntensity = 1.0;
          break;
      }

      _debugMessage = 'Lighting changed to: $_environmentLighting';
    });
  }

  /// Get the environment map based on current lighting setting
  String _getEnvironmentMap() {
    switch (_environmentLighting) {
      case 'sunset':
        return 'legacy';
      case 'night':
        return 'neutral';
      case 'bright':
        return 'lit';
      case 'neutral':
      default:
        return 'neutral';
    }
  }

  /// Build an action button with improved styling
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isSelected = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.blue.withAlpha(100)
                    : Colors.black.withAlpha(100),
                blurRadius: isSelected ? 8 : 4,
                spreadRadius: isSelected ? 2 : 1,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.all(isSelected ? 14 : 12),
              backgroundColor: isSelected ? Colors.blue : Colors.white,
              foregroundColor: isSelected ? Colors.white : Colors.black,
              elevation: isSelected ? 6 : 4,
            ),
            child: Icon(icon, size: isSelected ? 22 : 20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSelected ? 14 : 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build the debug overlay with enhanced information
  Widget _buildDebugOverlay() {
    // Get resource manager for metrics
    final resourceManager = ResourceManager();

    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withAlpha(50),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: $_debugMessage',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Models: ${_displayedModels.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'AR Nodes: ${_arNodes.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Recognitions: ${widget.recognitions.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Lighting: $_environmentLighting (${_lightIntensity.toStringAsFixed(1)})',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'AR Session: ${_arManager.isSessionActive ? (_arManager.isSessionPaused ? "Paused" : "Active") : "Inactive"}',
              style: TextStyle(
                color: _arManager.isSessionActive
                    ? (_arManager.isSessionPaused
                        ? Colors.orange
                        : Colors.green)
                    : Colors.red,
                fontSize: 12,
              ),
            ),
            Text(
              'FPS: ${_arManager.currentFPS.toStringAsFixed(1)}',
              style: TextStyle(
                color:
                    _arManager.currentFPS > 24 ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
            Text(
              'Memory: ${(resourceManager.estimatedMemoryUsage).toStringAsFixed(1)} MB',
              style: TextStyle(
                color: resourceManager.isPerformanceDegraded
                    ? Colors.orange
                    : Colors.white,
                fontSize: 12,
              ),
            ),
            Text(
              'Cache: ${_modelManager.cacheSize} models',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'App State: ${resourceManager.isInForeground ? "Foreground" : "Background"}',
              style: TextStyle(
                color: resourceManager.isInForeground
                    ? Colors.green
                    : Colors.orange,
                fontSize: 12,
              ),
            ),
            Text(
              'Temperature: ${resourceManager.thermalManager.currentTemperature.toStringAsFixed(1)}°C',
              style: TextStyle(
                color: _getThermalStateColor(
                    resourceManager.thermalManager.currentThermalState),
                fontSize: 12,
              ),
            ),
            Text(
              'Thermal State: ${resourceManager.thermalManager.currentThermalState}',
              style: TextStyle(
                color: _getThermalStateColor(
                    resourceManager.thermalManager.currentThermalState),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get color for thermal state
  Color _getThermalStateColor(thermal.ThermalState state) {
    switch (state) {
      case thermal.ThermalState.normal:
        return Colors.green;
      case thermal.ThermalState.elevated:
        return Colors.orange;
      case thermal.ThermalState.critical:
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  /// Build the empty state message with AR guidance
  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AR icon with animation effect
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: Icon(
                Icons.view_in_ar,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            const Text(
              'Show an object to the camera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A 3D model will appear in augmented reality when an object is recognized',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // AR tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tips_and_updates,
                          color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AR Tips',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTipItem('Ensure good lighting for better detection'),
                  _buildTipItem('Hold the device steady for stable AR'),
                  _buildTipItem('Point at a flat surface for best results'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a tip item with icon
  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
