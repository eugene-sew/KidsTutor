import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

// Import our custom TFLite helper
import '../utils/tflite_helper.dart';

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
  int _inputSize = 224; // Default for many models, will adjust based on the model

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadModel();
    _loadLabelMappings();
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
      ResolutionPreset.medium, // Using medium resolution for better performance with ML
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
                      Theme.of(context).colorScheme.secondary
                    ),
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
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      children: [
        // Camera preview (mirrored)
        Positioned.fill(
          child: Transform.scale(
            scaleX: -1.0, // Flip horizontally for mirror effect
            child: CameraPreview(_cameraController!),
          ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                            Icon(Icons.visibility, color: Colors.green, size: 20.0),
                            SizedBox(width: 5),
                            Text(
                              'AI Ready',
                              style: TextStyle(color: Colors.white, fontSize: 14),
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Loading AI',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
        
        // Recognition results (bottom left)
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildRecognitionResults(),
          ),
        ),

        // Mode indicator
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                'Explore Mode - Show an object to the camera',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
      _interpreter = await TFLiteHelper.loadModelFromAssets('lib/ml_models/model_unquant.tflite');
      
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
        final labelsData = await rootBundle.loadString('assets/lib/ml_models/labels.txt');
        _processLabelData(labelsData);
      } catch (e) {
        debugPrint('Trying alternative path for labels: $e');
        try {
          final labelsData = await rootBundle.loadString('lib/ml_models/labels.txt');
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
      })
      .toList();
    
    debugPrint('Labels loaded: ${_labelsList.length}');
  }

  // Load label mappings from A,B,C to Apple,Ball,Cat
  Future<void> _loadLabelMappings() async {
    try {
      // Load letter labels (A, B, C, etc.) with fallback
      final String? letterLabelsText = await _loadAssetText('assets/lib/ml_models/labels.txt') ??
                                       await _loadAssetText('lib/ml_models/labels.txt');

      final String? namedLabelsText = await _loadAssetText('assets/lib/ml_models/labels_named.txt') ??
                                      await _loadAssetText('lib/ml_models/labels_named.txt');

      if (letterLabelsText == null || namedLabelsText == null) {
        debugPrint('Failed to load one or more label files.');
        return;
      }

      final List<String> letterLabels = letterLabelsText.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.split(' ');
            return parts.length >= 2 ? parts[1].trim() : '';
          })
          .where((label) => label.isNotEmpty)
          .toList();
      
      final List<String> namedLabels = namedLabelsText.split('\n')
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
        for (int i = 0; i < letterLabels.length && i < namedLabels.length; i++) {
          mappings[letterLabels[i]] = namedLabels[i];
        }
        
        if (mounted) {
          setState(() {
            _labelMappings = mappings;
          });
        }
        
        debugPrint('Label mappings loaded: $_labelMappings');
      } else {
        debugPrint('Could not create mappings, one of the label lists is empty.');
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
    _predictionTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_cameraController != null && _cameraController!.value.isInitialized && _isModelLoaded) {
        // Add simple debounce for better performance
        if (!_isProcessingImage) {
          _predictImage();
        }
      }
    });
  }

  // Perform image prediction using TFLite
  Future<void> _predictImage() async {
    if (!_cameraController!.value.isInitialized || !_isModelLoaded || _interpreter == null) {
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
      final processedImg = img.copyResize(
        imgLib,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear
      );
      
      // Run inference with TFLite model
      final recognitions = await _runInference(processedImg);
      
      // Delete the temporary image file
      try {
        File(imageFile.path).deleteSync();
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }
      
      if (recognitions.isNotEmpty) {
        setState(() {
          _recognitions = recognitions;
        });
        debugPrint('Recognition results: $_recognitions');
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
      print('Model not loaded');
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
      
      // Add letter labels to recognitions
      final enhancedRecognitions = recognitions.map((recognition) {
        final int index = recognition['index'];
        final String letterLabel = index < _labelsList.length ? _labelsList[index] : '?';
        
        return {
          ...recognition,
          'label': '$index $letterLabel',
        };
      }).toList();
      
      return enhancedRecognitions;
    } catch (e) {
      print('Error running model inference: $e');
      return [];
    }
  }
  
  // Note: We removed the _imageToByteListFloat32 and _processModelOutput methods since they are now handled by TFLiteHelper class

  // Build the recognition results widget
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
          final String label = recognition['label'] ?? '';
          final double confidence = recognition['confidence'] ?? 0.0;
          // Extract the letter label directly from the label string
          final String letterLabel = label.split(' ').length > 1 ? label.split(' ')[1] : '';
          final String namedLabel = _labelMappings[letterLabel] ?? 'Unknown';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getConfidenceColor(confidence).withOpacity(0.5), width: 1),
            ),
            child: Row(
              children: [
                // Confidence indicator
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
                // Label display
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
                          style: const TextStyle(color: Colors.white, fontSize: 16),
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
        }).toList(),
      ],
    );
  }

  // Get color based on confidence level
  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.85) {
      // High confidence - vibrant green
      return const Color(0xFF4CAF50);
    } else if (confidence > 0.70) {
      // Good confidence - lime green
      return const Color(0xFF8BC34A);
    } else if (confidence > 0.55) {
      // Moderate confidence - amber
      return const Color(0xFFFFC107);
    } else if (confidence > 0.40) {
      // Low confidence - orange
      return const Color(0xFFFF9800);
    } else {
      // Very low confidence - red
      return const Color(0xFFF44336);
    }
  }
}
