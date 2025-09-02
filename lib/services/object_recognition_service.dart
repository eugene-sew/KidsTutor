import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import '../utils/tts_service.dart';

class ObjectRecognitionService {
  static final ObjectRecognitionService _instance = ObjectRecognitionService._internal();
  factory ObjectRecognitionService() => _instance;
  ObjectRecognitionService._internal();

  tfl.Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  
  // Object to 3D model mapping
  final Map<String, String> _objectToModel = {
    'Apple': 'assets/3d_models/apple.glb',
    'Ball': 'assets/3d_models/default.glb',
    'Cat': 'assets/3d_models/default.glb',
    'Dog': 'assets/3d_models/default.glb',
    'Elephant': 'assets/3d_models/elephant.glb',
    'Fish': 'assets/3d_models/fish.glb',
    'Soccer': 'assets/3d_models/soccer.glb',
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load TFLite model
      _interpreter = await tfl.Interpreter.fromAsset('lib/ml_models/model_unquant.tflite');
      
      // Load labels
      final labelsData = await rootBundle.loadString('lib/ml_models/labels_named.txt');
      _labels = labelsData.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.split(' ').skip(1).join(' '))
          .toList();
      
      _isInitialized = true;
      print('Object recognition initialized with ${_labels.length} labels');
    } catch (e) {
      print('Error initializing object recognition: $e');
      throw e;
    }
  }

  Future<RecognitionResult?> recognizeObject(Uint8List imageBytes) async {
    if (!_isInitialized || _interpreter == null) {
      await initialize();
    }

    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Preprocess image for model input
      final resized = img.copyResize(image, width: 224, height: 224);
      final input = _imageToByteListFloat32(resized);

      // Run inference
      final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
      _interpreter!.run(input, output);

      // Find highest confidence prediction
      final predictions = output[0] as List<double>;
      double maxConfidence = 0.0;
      int maxIndex = 0;

      for (int i = 0; i < predictions.length; i++) {
        if (predictions[i] > maxConfidence) {
          maxConfidence = predictions[i];
          maxIndex = i;
        }
      }

      // Log recognition results
      if (maxIndex < _labels.length) {
        final objectName = _labels[maxIndex];
        final confidencePercent = (maxConfidence * 100).toStringAsFixed(1);
        print('🔍 Recognition: $objectName - Confidence: $confidencePercent%');
        
        // Only return result if confidence is above threshold
        if (maxConfidence > 0.5) {
          final modelPath = _objectToModel[objectName];
          
          return RecognitionResult(
            objectName: objectName,
            confidence: maxConfidence,
            modelPath: modelPath,
          );
        }
      }

      return null;
    } catch (e) {
      print('❌ Error during recognition: $e');
      return null;
    }
  }

  Float32List _imageToByteListFloat32(img.Image image) {
    final convertedBytes = Float32List(1 * 224 * 224 * 3);
    final buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (int i = 0; i < 224; i++) {
      for (int j = 0; j < 224; j++) {
        final pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - 127.5) / 127.5;
        buffer[pixelIndex++] = (pixel.g - 127.5) / 127.5;
        buffer[pixelIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }
    return convertedBytes;
  }

  List<String> get availableObjects => _objectToModel.keys.toList();
  
  String? getModelPath(String objectName) => _objectToModel[objectName];
}

class RecognitionResult {
  final String objectName;
  final double confidence;
  final String? modelPath;

  RecognitionResult({
    required this.objectName,
    required this.confidence,
    this.modelPath,
  });

  @override
  String toString() => 'RecognitionResult(object: $objectName, confidence: ${confidence.toStringAsFixed(2)})';
}
