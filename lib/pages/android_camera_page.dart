import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import '../utils/tts_service.dart';

class AndroidCameraPage extends StatefulWidget {
  const AndroidCameraPage({super.key});

  @override
  State<AndroidCameraPage> createState() => _AndroidCameraPageState();
}

class _AndroidCameraPageState extends State<AndroidCameraPage> {
  CameraController? _cameraController;
  Timer? _timer;
  String _status = 'Loading model...';
  bool _isActive = false;
  String _lastRecognizedObject = '';
  double _lastConfidence = 0.0;

  tfl.Interpreter? _interpreter;
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      setState(() {
        _status = 'Camera error: $e';
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter =
          await tfl.Interpreter.fromAsset('lib/ml_models/model_unquant.tflite');

      final labelsData =
          await rootBundle.loadString('lib/ml_models/labels_named.txt');
      _labels = labelsData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.split(' ').skip(1).join(' '))
          .toList();

      setState(() {
        _status = 'Ready - Tap play to start';
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading model: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: CircularProgressIndicator(),
            ),
          
          // Status overlay
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Recognition result overlay
          if (_lastRecognizedObject.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Found: $_lastRecognizedObject',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Confidence: ${(_lastConfidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Play/Pause button
          Positioned(
            top: 60,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              onPressed: _toggle,
              backgroundColor: _isActive ? Colors.red : Colors.green,
              child: Icon(
                _isActive ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle() {
    if (_interpreter == null || _cameraController == null) return;

    if (_isActive) {
      _timer?.cancel();
      _isActive = false;
      setState(() {
        _lastRecognizedObject = '';
      });
    } else {
      _isActive = true;
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _recognize());
    }
    setState(() {});
  }

  Future<void> _recognize() async {
    if (_interpreter == null || 
        _cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _labels.isEmpty) return;

    try {
      // Capture image from camera
      final image = await _cameraController!.takePicture();
      final imageBytes = await image.readAsBytes();

      // Decode and resize the image
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        print('❌ Could not decode image');
        return;
      }

      final resizedImage = img.copyResize(decodedImage, width: 224, height: 224);

      // Normalize and create the input tensor
      final input = List.generate(
          1,
          (_) => List.generate(
              224,
              (y) => List.generate(224, (x) {
                    final pixel = resizedImage.getPixel(x, y);
                    return [
                      (pixel.r - 127.5) / 127.5,
                      (pixel.g - 127.5) / 127.5,
                      (pixel.b - 127.5) / 127.5,
                    ];
                  })));

      // Create output tensor
      final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      // Find highest confidence
      final predictions = output[0];
      double maxConfidence = 0.0;
      int maxIndex = 0;

      for (int i = 0; i < predictions.length; i++) {
        if (predictions[i] > maxConfidence) {
          maxConfidence = predictions[i];
          maxIndex = i;
        }
      }

      if (maxIndex < _labels.length && maxConfidence > 0.5) {
        final obj = _labels[maxIndex];
        print('🔍 Recognition: $obj - Confidence: ${(maxConfidence * 100).toStringAsFixed(1)}%');

        setState(() {
          _status = 'Found $obj! ${(maxConfidence * 100).toStringAsFixed(1)}%';
          _lastRecognizedObject = obj;
          _lastConfidence = maxConfidence;
        });

        // Speak the recognized object
        try {
          await TtsService().speak('I see $obj');
        } catch (e) {
          print('TTS error: $e');
        }

        // Auto-pause on high confidence
        if (maxConfidence > 0.8) {
          print('🛑 High confidence - auto-pausing');
          _timer?.cancel();
          _isActive = false;
          setState(() {
            _status = 'High confidence - paused';
          });
        }
      } else {
        setState(() {
          _status = 'Looking for objects...';
        });
      }
    } catch (e) {
      print('❌ Recognition error: $e');
      setState(() {
        _status = 'Recognition error: $e';
      });
    }
  }
}
