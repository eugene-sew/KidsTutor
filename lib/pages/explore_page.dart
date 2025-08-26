import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

// Import our TFLite helper
import '../utils/tflite_helper.dart';

// Import AR components
import '../ar/models/ar_model.dart';
import '../ar/utils/ar_error_handler.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
// TTS Service
import '../services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;

  // TFLite related variables
  tfl.Interpreter? _interpreter;
  bool _isModelLoaded = false;
  List<Map<String, dynamic>> _recognitions = [];
  List<String> _labelsList = [];
  Map<String, String> _labelMappings = {}; // Maps A, B, C to Apple, Ball, Cat
  Timer? _predictionTimer;
  bool _isProcessingImage = false; // Flag to prevent overlapping processing
  int _inputSize =
      224; // Default for many models, will adjust based on the model

  // AR related variables
  bool _isARModeActive = false;
  ARModel? _selectedModel;
  final ARErrorHandler _errorHandler = ARErrorHandler();
  List<String> _available3DModels = []; // List of model asset paths
  // Recognition control variables
  bool _isRecognitionPaused = false; // When true, background recognition is paused

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadModel();
    _loadLabelMappings();
    _load3DModels();
    _checkPermissionsAndInitCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _interpreter?.close();
    _predictionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize the camera
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_cameraController!.description);
    }
  }

  Future<void> _checkPermissionsAndInitCamera() async {
    final status = await Permission.camera.request();
    setState(() {
      _isCameraPermissionGranted = status.isGranted;
    });

    if (_isCameraPermissionGranted) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initCamera(_cameras[0]);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset
          .medium, // Using medium resolution for better performance with ML
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await cameraController.initialize();
      setState(() {
        _cameraController = cameraController;
        _isCameraInitialized = true;
      });

      // Start image prediction on a timer
      _startImagePrediction();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore and Learn'),
        actions: [
          // Model status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isModelLoaded
                ? const Icon(Icons.check_circle, color: Colors.green)
                : SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.secondary),
                    ),
                  ),
          ),
        ],
      ),
      body: _isCameraPermissionGranted
          ? _cameraController != null && _cameraController!.value.isInitialized
              ? _buildCameraPreview()
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Initializing camera...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )
          : _buildPermissionDeniedWidget(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleARMode,
        backgroundColor: _isARModeActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[600],
        icon: Icon(
          _isARModeActive ? Icons.view_in_ar : Icons.camera_alt,
          color: Colors.white,
        ),
        label: Text(
          _isARModeActive ? 'AR Mode' : 'Camera',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      children: [
        // Camera preview (always show as background)
        Positioned.fill(
          child: Transform.scale(
            scaleX: -1.0, // Flip horizontally for mirror effect
            child: CameraPreview(_cameraController!),
          ),
        ),

        // AR overlay when AR mode is active
        if (_isARModeActive && _selectedModel != null)
          Positioned.fill(
            child: _build3DModelOverlay(),
          ),

        // Camera frame with border
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isProcessingImage
                    ? Colors.blue.withOpacity(0.7)
                    : _isModelLoaded
                        ? Colors.green.withOpacity(0.5)
                        : Colors.orange.withOpacity(0.5),
                width: 4.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),

        // Status indicator (top right)
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: _isProcessingImage
                ? Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Processing',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        )
                      ],
                    ),
                  )
                : _isModelLoaded
                    ? Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.visibility,
                                color: Colors.green, size: 20.0),
                            SizedBox(width: 5),
                            Text(
                              'AI Ready',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Loading AI',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
          ),
        ),

        // Recognition results (bottom left) - only show in camera mode
        if (!_isARModeActive)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildRecognitionResults(),
            ),
          ),

        // AR model info overlay (top center) - only show in AR mode
        if (_isARModeActive && _selectedModel != null)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                      red: 0, green: 0, blue: 0, alpha: 153), // 0.6 opacity
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(
                        red: 255,
                        green: 255,
                        blue: 255,
                        alpha: 77), // 0.3 opacity
                    width: 1,
                  ),
                ),
                child: Text(
                  '🎯 ${_selectedModel!.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

        // Manual recognition trigger (bottom-right) - shown in AR mode
        if (_isARModeActive)
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              heroTag: 'scan_fab',
              onPressed: _triggerRecognition,
              backgroundColor: _isRecognitionPaused
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.document_scanner, color: Colors.white),
              label: Text(
                _isRecognitionPaused ? 'Scan' : 'Scanning...',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPermissionDeniedWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.no_photography,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera permission denied',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please grant camera permission to use the explore feature',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await _checkPermissionsAndInitCamera();
            },
            child: const Text('Request Permission'),
          ),
        ],
      ),
    );
  }

  // Load the TFLite model
  Future<void> _loadModel() async {
    try {
      // Load the model from the correct asset path.
      _interpreter = await TFLiteHelper.loadModelFromAssets(
          'lib/ml_models/model_unquant.tflite');

      if (_interpreter == null) {
        debugPrint('Failed to load model: interpreter is null');
        return;
      }

      // Get input shape to determine processing parameters
      final inputShape = _interpreter!.getInputTensor(0).shape;
      _inputSize = inputShape[1]; // Assuming square input (height = width)

      setState(() {
        _isModelLoaded = true;
      });
      debugPrint('TFLite model loaded successfully. Input size: $_inputSize');

      // Load labels directly with both path options
      try {
        final labelsData =
            await rootBundle.loadString('assets/lib/ml_models/labels.txt');
        _processLabelData(labelsData);
      } catch (e) {
        debugPrint('Trying alternative path for labels: $e');
        try {
          final labelsData =
              await rootBundle.loadString('lib/ml_models/labels.txt');
          _processLabelData(labelsData);
        } catch (e) {
          debugPrint('Failed to load labels from all paths: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to load TFLite model: $e');
    }
  }

  // Process label data
  void _processLabelData(String labelsData) {
    _labelsList = labelsData
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
      final parts = line.split(' ');
      return parts.length > 1 ? parts[1] : parts[0];
    }).toList();

    debugPrint('Labels loaded: ${_labelsList.length}');
  }

  // Load label mappings from A,B,C to Apple,Ball,Cat
  Future<void> _loadLabelMappings() async {
    try {
      // Load letter labels (A, B, C, etc.) with fallback
      final String? letterLabelsText =
          await _loadAssetText('assets/lib/ml_models/labels.txt') ??
              await _loadAssetText('lib/ml_models/labels.txt');

      final String? namedLabelsText =
          await _loadAssetText('assets/lib/ml_models/labels_named.txt') ??
              await _loadAssetText('lib/ml_models/labels_named.txt');

      if (letterLabelsText == null || namedLabelsText == null) {
        debugPrint('Failed to load one or more label files.');
        return;
      }

      final List<String> letterLabels = letterLabelsText
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.split(' ');
            return parts.length >= 2 ? parts[1].trim() : '';
          })
          .where((label) => label.isNotEmpty)
          .toList();

      final List<String> namedLabels = namedLabelsText
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.split(' ');
            return parts.length >= 2 ? parts[1].trim() : '';
          })
          .where((label) => label.isNotEmpty)
          .toList();

      // Create mapping from letters to names
      if (letterLabels.isNotEmpty && namedLabels.isNotEmpty) {
        final Map<String, String> mappings = {};
        for (int i = 0;
            i < letterLabels.length && i < namedLabels.length;
            i++) {
          mappings[letterLabels[i]] = namedLabels[i];
        }

        if (mounted) {
          setState(() {
            _labelMappings = mappings;
          });
        }

        debugPrint('Label mappings loaded: $_labelMappings');
      } else {
        debugPrint(
            'Could not create mappings, one of the label lists is empty.');
      }
    } catch (e) {
      debugPrint('Failed to load label mappings: $e');
    }
  }

  // Helper to load asset text with error handling
  Future<String?> _loadAssetText(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      // It's okay for this to fail, as we have fallbacks.
      return null;
    }
  }

  // Start image prediction on a timer
  void _startImagePrediction() {
    _predictionTimer?.cancel();
    // Set to 1.2 seconds (1200ms) to balance responsiveness and performance
    // This gives enough time to process each frame while maintaining a smooth user experience
    _predictionTimer =
        Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          _isModelLoaded &&
          !_isRecognitionPaused) {
        // Add simple debounce for better performance
        if (!_isProcessingImage) {
          _predictImage();
        }
      }
    });
  }

  // Perform image prediction using TFLite
  Future<void> _predictImage() async {
    if (!_cameraController!.value.isInitialized ||
        !_isModelLoaded ||
        _interpreter == null) {
      return;
    }

    // Set processing flag to prevent multiple simultaneous processing
    if (_isProcessingImage) {
      debugPrint('Still processing previous image, skipping...');
      return;
    }

    try {
      setState(() {
        _isProcessingImage = true;
      });

      // Capture image from camera
      final XFile imageFile = await _cameraController!.takePicture();

      // Process the image for the model
      final imgLib = img.decodeImage(await File(imageFile.path).readAsBytes());
      if (imgLib == null) {
        debugPrint('Error decoding image');
        return;
      }

      // Resize and preprocess the image
      final processedImg = img.copyResize(imgLib,
          width: _inputSize,
          height: _inputSize,
          interpolation: img.Interpolation.linear);

      // Run inference with TFLite model
      final recognitions = await _runInference(processedImg);

      // Delete the temporary image file
      try {
        File(imageFile.path).deleteSync();
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }

      if (recognitions.isNotEmpty) {
        // Log detailed recognition results
        print('🔍 RECOGNITION RESULTS:');
        for (int i = 0; i < recognitions.length; i++) {
          final recognition = recognitions[i];
          final label = recognition['label'] ?? 'Unknown';
          final confidence = (recognition['confidence'] ?? 0.0) * 100;
          final mappedName = _labelMappings[label] ?? label;
          print('  ${i + 1}. Label: "$label" -> "$mappedName" | Confidence: ${confidence.toStringAsFixed(1)}%');
        }

        setState(() {
          _recognitions = recognitions;
        });

        if (_isARModeActive) {
          print('🎯 AR MODE ACTIVE - Checking for 3D model...');
          _updateARModelFromRecognition();

          // Pause background recognition if top result is confident enough
          final double topConfidence =
              (_recognitions.first['confidence'] ?? 0.0);
          if (topConfidence >= 0.8) {
            print('⏸️  Pausing recognition (confidence >= 0.8): $topConfidence');
            _predictionTimer?.cancel();
            if (mounted) {
              setState(() {
                _isRecognitionPaused = true;
              });
            }
            // Optional user feedback
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recognition paused. Tap Scan to rescan.'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            // Speak child-friendly phrase, e.g., "A is for Apple" if enabled in settings
            try {
              final prefs = await SharedPreferences.getInstance();
              final enabled = prefs.getBool('tts_auto_speak_on_pause') ?? true;
              if (enabled) {
                final String letter = _recognitions.first['label'] ?? '';
                final String word = _labelMappings[letter] ?? letter;
                if (letter.isNotEmpty && word.isNotEmpty) {
                  TTSService().speak('$letter is for $word');
                }
              }
            } catch (_) {}
          }
        }

        debugPrint('Recognition results: $_recognitions');
      } else {
        print('🔍 No objects recognized in current frame');
      }
    } catch (e) {
      debugPrint('Error during image prediction: $e');
    } finally {
      // Reset processing flag when done
      setState(() {
        _isProcessingImage = false;
      });
    }
  }

  // Run inference with TFLite model
  Future<List<Map<String, dynamic>>> _runInference(img.Image image) async {
    if (!_isModelLoaded || _interpreter == null) {
      debugPrint('Model not loaded');
      return [];
    }

    try {
      // Use our TFLite helper to run the model
      final recognitions = await TFLiteHelper.runModelOnImage(
        interpreter: _interpreter!,
        image: image,
        inputSize: _inputSize,
        labelsCount: _labelsList.length,
        confidenceThreshold: 0.5,
        topK: 3,
      );

      // Add letter labels and position information to recognitions
      final enhancedRecognitions = recognitions.map((recognition) {
        final int index = recognition['index'];
        final String letterLabel =
            index < _labelsList.length ? _labelsList[index] : '?';

        // For now, we'll use a simulated position in the center of the screen
        // In a real implementation with object detection, this would be the actual
        // bounding box center of the detected object
        final position = {
          'x': 0.5, // Normalized x position (0-1)
          'y': 0.5, // Normalized y position (0-1)
        };

        // For demonstration purposes, we'll vary the position slightly based on the letter
        // to show different positions for different letters
        if (letterLabel.isNotEmpty) {
          final letterCode = letterLabel.codeUnitAt(0);
          position['x'] =
              0.3 + ((letterCode % 10) / 20); // Vary x between 0.3 and 0.8
          position['y'] =
              0.3 + ((letterCode % 5) / 10); // Vary y between 0.3 and 0.8
        }

        return {
          ...recognition,
          'label': letterLabel, // Return just the letter label
          'position': position,
        };
      }).toList();

      return enhancedRecognitions;
    } catch (e) {
      debugPrint('Error running model inference: $e');
      return [];
    }
  }

  Widget _buildRecognitionResults() {
    if (_recognitions.isEmpty) {
      return const Center(
        child: Text(
          'Looking for objects...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
            SizedBox(width: 6),
            Text(
              'I see:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recognitions.take(3).map((recognition) {
          final String letterLabel = recognition['label'] ?? '';
          final double confidence = recognition['confidence'] ?? 0.0;
          final String namedLabel = _labelMappings[letterLabel] ?? 'Unknown';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _getConfidenceColor(confidence).withOpacity(0.5),
                  width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(confidence),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${(confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        letterLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          children: [
                            const TextSpan(text: 'is for '),
                            TextSpan(
                              text: namedLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.85) {
      return const Color(0xFF4CAF50);
    } else if (confidence > 0.70) {
      return const Color(0xFF8BC34A);
    } else if (confidence > 0.55) {
      return const Color(0xFFFFC107);
    } else if (confidence > 0.40) {
      return const Color(0xFFFF9800);
    } else {
      return const Color(0xFFF44336);
    }
  }

  void _toggleARMode() {
    final previousMode = _isARModeActive;
    
    setState(() {
      _isARModeActive = !_isARModeActive;
    });

    print('🔄 MODE TOGGLE: ${previousMode ? "AR" : "Camera"} -> ${_isARModeActive ? "AR" : "Camera"}');
    
    if (_isARModeActive) {
      print('🎯 AR Mode activated - will display 3D models when objects detected');
      // Start AR prediction if not paused
      if (_isRecognitionPaused) {
        // Keep paused state; user can trigger with Scan
        _predictionTimer?.cancel();
      } else {
        _startARModePrediction();
      }
    } else {
      print('📷 Camera mode activated - showing recognition results only');
      if (_selectedModel != null) {
        print('🗑️  Clearing current 3D model: ${_selectedModel!.name}');
        setState(() {
          _selectedModel = null;
        });
      }
      // Resume background prediction in camera mode
      setState(() {
        _isRecognitionPaused = false;
      });
      _startImagePrediction();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isARModeActive
            ? 'AR mode activated - Show objects to see 3D models'
            : 'Camera mode activated'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startARModePrediction() {
    _predictionTimer?.cancel();
    _predictionTimer =
        Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          _isModelLoaded &&
          !_isRecognitionPaused) {
        if (!_isProcessingImage) {
          _predictImage();
        }
      }
    });
  }

  // Manually trigger a single recognition while in AR mode
  void _triggerRecognition() {
    if (!_isARModeActive) return;
    // Allow a single-shot prediction even if paused
    if (!_isProcessingImage) {
      setState(() {
        // Keep paused state; just perform one prediction
      });
      _predictImage();
    }
  }

  Future<void> _load3DModels() async {
    print('📦 Loading 3D models from assets...');
    
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      final modelPaths = manifestMap.keys
          .where((String key) => key.startsWith('assets/3d_models/'))
          .toList();

      print('📋 Found ${modelPaths.length} 3D model files:');
      for (int i = 0; i < modelPaths.length; i++) {
        print('   ${i + 1}. ${modelPaths[i]}');
      }

      setState(() {
        _available3DModels = modelPaths;
      });
      
      print('✅ 3D models loaded successfully');
    } catch (e) {
      print('❌ Error loading 3D models: $e');
    }
  }

  void _updateARModelFromRecognition() {
    if (_recognitions.isEmpty) {
      print('⚠️  No recognitions available for AR model update');
      return;
    }

    final topRecognition = _recognitions.first;
    final confidence = topRecognition['confidence'] as double;
    final label = topRecognition['label'].toString();
    final confidencePercent = (confidence * 100).toStringAsFixed(1);

    print('🎯 AR MODEL UPDATE - Top recognition: "$label" with ${confidencePercent}% confidence');

    // Only update if confidence is high
    if (confidence < 0.85) {
      print('❌ Confidence too low (${confidencePercent}% < 85%) - clearing 3D model');
      if (_selectedModel != null) {
        print('🗑️  Removing current 3D model: ${_selectedModel!.name}');
        setState(() {
          _selectedModel = null; // Clear model if confidence drops
        });
      }
      return;
    }

    final modelName = label.toLowerCase();
    final modelDisplayName = _labelMappings[label] ?? label;

    print('✅ High confidence detected! Searching for 3D model...');
    print('   - Original label: "$label"');
    print('   - Model filename to search: "$modelName.glb"');
    print('   - Display name: "$modelDisplayName"');
    print('   - Available 3D models: ${_available3DModels.length} total');

    // Find the corresponding model path
    var modelPath = _available3DModels.firstWhere(
      (path) => path.contains('/$modelName.glb'),
      orElse: () => '',
    );

    bool usingFallback = false;
    if (modelPath.isEmpty) {
      print('🔄 No specific model found for "$modelName.glb" - using fallback');
      modelPath = 'assets/3d_models/default.glb';
      usingFallback = true;
    } else {
      print('🎉 Found specific 3D model: $modelPath');
    }

    final newModel = ARModel(
      id: usingFallback ? 'default' : modelName,
      name: usingFallback ? 'Magic Box' : modelDisplayName,
      modelPath: modelPath,
      scale: 0.1,
      pronunciation: modelDisplayName,
    );

    // Only update the state if the model has changed to prevent unnecessary rebuilds.
    if (_selectedModel?.modelPath != newModel.modelPath) {
      print('🚀 TRIGGERING 3D MODEL:');
      print('   - Model ID: ${newModel.id}');
      print('   - Model Name: ${newModel.name}');
      print('   - Model Path: ${newModel.modelPath}');
      print('   - Using Fallback: $usingFallback');
      
      setState(() {
        _selectedModel = newModel;
      });
    } else {
      print('🔄 Same model already loaded, no update needed');
    }
  }

  Widget _build3DModelOverlay() {
    if (_selectedModel == null) return const SizedBox.shrink();

    return Center(
      child: GestureDetector(
        onTap: () => _handleModelInteraction(_selectedModel!),
        child: Container(
          width: 200,
          height: 200,
          child: ModelViewer(
            src: _selectedModel!.modelPath,
            alt: _selectedModel!.name,
            ar: true,
            autoRotate: true,
            cameraControls: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  void _handleModelInteraction(ARModel model) {
    setState(() {
      _selectedModel = model;
    });

    // Show information about the model
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pronunciation: ${model.pronunciation}',
                        style: const TextStyle(
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (model.funFact != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(
                                red: 230, green: 240, blue: 255, alpha: 255),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fun Fact:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                model.funFact!,
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
