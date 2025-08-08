// File IO is handled elsewhere
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// A helper class for TensorFlow Lite operations
class TFLiteHelper {
  /// Loads a TFLite model from assets
  static Future<tfl.Interpreter?> loadModelFromAssets(String modelPath) async {
    try {
      // Load model from assets using isolate
      final modelData = await rootBundle.load(modelPath);
      return tfl.Interpreter.fromBuffer(modelData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading model: $e');
      return null;
    }
  }

  /// Processes an image and runs inference with the TFLite model
  static Future<List<Map<String, dynamic>>> runModelOnImage({
    required tfl.Interpreter interpreter,
    required img.Image image,
    required int inputSize,
    required int labelsCount,
    double confidenceThreshold = 0.5,
    int topK = 3,
  }) async {
    try {
      // Convert the image to input tensor format
      final input = _imageToByteListFloat32(image, inputSize);

      // Create output tensor
      final outputShape = interpreter.getOutputTensor(0).shape;
      // The model output is a 2D tensor (e.g., [1, 26]), so we need a matching buffer.
      final outputBuffer = List.generate(
        outputShape[0],
        (index) => List<double>.filled(outputShape[1], 0),
      );

      // Reshape input tensor to the required shape [1, 224, 224, 3]
      final inputTensor = interpreter.getInputTensor(0);
      final inputShape = inputTensor.shape;

      // Ensure input tensor is float32 and calculate expected size
      if (inputTensor.type != tfl.TensorType.float32) {
        throw Exception(
            'Model input tensor is not Float32. This helper is not compatible.');
      }
      final expectedSizeInBytes = inputShape.reduce((a, b) => a * b) * 4;

      if (input.lengthInBytes != expectedSizeInBytes) {
        throw Exception(
            'Input tensor size mismatch. Expected $expectedSizeInBytes bytes, but got ${input.lengthInBytes} bytes.');
      }
      final reshapedInput = input.buffer.asFloat32List().reshape(inputShape);

      // Prepare input and output tensors
      final inputs = [reshapedInput];
      final outputs = {0: outputBuffer};

      // Run inference
      interpreter.runForMultipleInputs(inputs, outputs);

      // Process results
      // The output is a list containing a single list of probabilities.
      final resultsList = outputBuffer[0].sublist(0, labelsCount);

      // Format results
      final List<Map<String, dynamic>> recognitions = [];

      // Find indices of top k confidence values
      List<MapEntry<int, double>> indexed = [];
      for (int i = 0; i < resultsList.length; i++) {
        indexed.add(MapEntry(i, resultsList[i]));
      }

      // Sort by confidence (highest first)
      indexed.sort((a, b) => b.value.compareTo(a.value));

      // Get top k results
      final topResults = indexed.take(topK).toList();

      // Format the results
      for (var result in topResults) {
        // Skip if confidence is too low
        if (result.value < confidenceThreshold) continue;

        recognitions.add({
          'index': result.key,
          'label': '${result.key}',
          'confidence': result.value,
        });
      }

      return recognitions;
    } catch (e) {
      print('Error running model inference: $e');
      return [];
    }
  }

  /// Convert image to tensor input format
  static Float32List _imageToByteListFloat32(img.Image image, int inputSize) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    // Create a resized copy of the image with the required input size
    final resizedImage = img.copyResize(image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear);

    // Process each pixel
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        // Get the pixel color
        final pixel = resizedImage.getPixel(x, y);

        // Extract RGB components (the Pixel class from image 4.x has r, g, b properties)
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Normalize pixel values to [-1, 1] range as required by the model
        buffer[pixelIndex++] = (r - 127.5) / 127.5;
        buffer[pixelIndex++] = (g - 127.5) / 127.5;
        buffer[pixelIndex++] = (b - 127.5) / 127.5;
      }
    }
    return convertedBytes;
  }
}
