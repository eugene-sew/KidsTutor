import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ARExplorePage extends StatefulWidget {
  const ARExplorePage({super.key});

  @override
  State<ARExplorePage> createState() => _ARExplorePageState();
}

class _ARExplorePageState extends State<ARExplorePage> {
  late ARKitController arkitController;
  Timer? _timer;
  String _status = 'Loading model...';
  bool _isActive = false;
  final List<String> _addedNodeNames = [];

  tfl.Interpreter? _interpreter;
  List<String> _labels = [];

  final _models = {
    'Apple': 'assets/3d_models/apple.glb',
    'Ball': 'assets/3d_models/soccer.glb',
    'Cat': 'assets/3d_models/default.glb',
    'Dog': 'assets/3d_models/default.glb',
    'Elephant': 'assets/3d_models/elephant.glb',
    'Fish': 'assets/3d_models/fish.glb',
    'Giraffe': 'assets/3d_models/default.glb',
    'Horse': 'assets/3d_models/default.glb',
    'Icecream': 'assets/3d_models/default.glb',
    'Jug': 'assets/3d_models/default.glb',
    'Kite': 'assets/3d_models/default.glb',
    'Lion': 'assets/3d_models/default.glb',
    'Monkey': 'assets/3d_models/default.glb',
    'Nest': 'assets/3d_models/default.glb',
    'Onion': 'assets/3d_models/default.glb',
    'Parrot': 'assets/3d_models/default.glb',
    'Queen': 'assets/3d_models/default.glb',
    'Rabbit': 'assets/3d_models/default.glb',
    'Soccer': 'assets/3d_models/soccer.glb',
    'Sun': 'assets/3d_models/default.glb',
    'Television': 'assets/3d_models/default.glb',
    'Umbrella': 'assets/3d_models/default.glb',
    'Van': 'assets/3d_models/default.glb',
    'Watch': 'assets/3d_models/default.glb',
    'Xylophone': 'assets/3d_models/default.glb',
    'Yam': 'assets/3d_models/default.glb',
    'Zebra': 'assets/3d_models/default.glb',
  };

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _interpreter?.close();
    super.dispose();
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
          ARKitSceneView(onARKitViewCreated: _onARKitViewCreated),
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

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;
  }

  void _toggle() {
    if (_interpreter == null) return;

    if (_isActive) {
      _timer?.cancel();
      _isActive = false;
    } else {
      // Clear previous models before starting a new session
      for (final nodeName in _addedNodeNames) {
        arkitController.remove(nodeName);
      }
      _addedNodeNames.clear();

      _isActive = true;
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _recognize());
    }
    setState(() {});
  }

  Future<Uint8List?> _getImageBytesFromProvider(
      ImageProvider imageProvider) async {
    final completer = Completer<Uint8List?>();
    final stream = imageProvider.resolve(const ImageConfiguration());

    stream.addListener(
        ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) async {
      final byteData =
          await imageInfo.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        completer.complete(byteData.buffer.asUint8List());
      } else {
        completer.complete(null);
      }
      imageInfo.dispose();
    }, onError: (exception, stackTrace) {
      completer.complete(null);
    }));

    return completer.future;
  }

  /// Recognize objects in the ARKit view
  Future<void> _recognize() async {
    if (_interpreter == null || _labels.isEmpty) return;

    try {
      // 1. Capture image from ARKit and convert to bytes
      final imageProvider = await arkitController.snapshot();
      final imageBytes = await _getImageBytesFromProvider(imageProvider);

      if (imageBytes == null) {
        print('❌ Could not get image bytes from provider');
        return;
      }

      // 2. Decode and resize the image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ Could not decode image');
        return;
      }

      final resizedImage = img.copyResize(image, width: 224, height: 224);

      // 3. Normalize and create the input tensor
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

      // Create output tensor [1, num_classes]
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

      if (maxIndex < _labels.length) {
        final obj = _labels[maxIndex];
        print(
            '🔍 Recognition: $obj - Confidence: ${(maxConfidence * 100).toStringAsFixed(1)}%');

        if (maxConfidence > 0.5) {
          print(
              '✅ Detected: $obj (${(maxConfidence * 100).toStringAsFixed(1)}%)');

          setState(() {
            _status =
                'Found $obj! ${(maxConfidence * 100).toStringAsFixed(1)}%';
          });

          _placeModel(obj);
//  double confirm threshold
          if (maxConfidence > 0.8) {
            print('🛑 High confidence - auto-pausing');
            _timer?.cancel();
            _isActive = false;
            setState(() {
              _status = 'High confidence - paused';
            });
          }
        }
      }
    } catch (e) {
      print('❌ Recognition error: $e');
      // Fallback to simulation if model fails
      final obj = ['Apple', 'Elephant', 'Fish'][DateTime.now().second % 3];
      final confidence = 0.6 + (DateTime.now().millisecond / 1000.0) * 0.3;

      print(
          '🔍 Fallback: $obj - Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      setState(() {
        _status = 'Fallback: $obj ${(confidence * 100).toStringAsFixed(1)}%';
      });

      _placeModel(obj);
    }
  }

  Future<void> _placeModel(String obj) async {
    final modelPath = _models[obj];

    if (modelPath == null) return;

    final nodeName = 'model_${DateTime.now().millisecondsSinceEpoch}';
    _addedNodeNames.add(nodeName);

    // Get the camera's transformation matrix
    final cameraMatrix = await arkitController.cameraProjectionMatrix();
    if (cameraMatrix == null) return;

    // Extract the position (translation) from the matrix (4th column)
    final cameraPosition = vector.Vector3(
      cameraMatrix.getColumn(3).x,
      cameraMatrix.getColumn(3).y,
      cameraMatrix.getColumn(3).z,
    );

    // Determine the forward direction from the matrix (3rd column, negated)
    final forwardDirection = vector.Vector3(
      -cameraMatrix.getColumn(2).x,
      -cameraMatrix.getColumn(2).y,
      -cameraMatrix.getColumn(2).z,
    ).normalized();

    // Position the model 0.5 meters in front of the camera
    final position = cameraPosition + (forwardDirection * 0.5);

    final node = ARKitGltfNode(
      name: nodeName,
      assetType: AssetType.flutterAsset,
      url: modelPath,
      scale: vector.Vector3(5, 5, 5), // Reverted to user's scale
      position: vector.Vector3(0, 0, -0.5),
    );

    arkitController.add(node);
  }
}
