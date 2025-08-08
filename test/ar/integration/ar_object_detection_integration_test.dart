import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../../lib/ar/utils/ar_manager.dart';
import '../../../lib/ar/utils/model_manager.dart';
import '../../../lib/ar/models/ar_model_mapping.dart';
import '../../../lib/ar/models/ar_model.dart';

void main() {
  group('AR and Object Detection Integration Tests', () {
    late ARManager arManager;
    late ModelManager modelManager;
    late ARModelMapping modelMapping;

    setUp(() async {
      arManager = ARManager();
      modelManager = ModelManager();
      modelMapping = ARModelMapping();
      
      // Initialize AR manager
      await arManager.initialize();
    });

    tearDown(() {
      arManager.dispose();
      modelManager.clearCache();
    });

    group('Object Detection to AR Model Pipeline', () {
      test('should convert object detection results to AR models', () async {
        // Simulate object detection results
        final recognitions = [
          {
            'label': '0 A',
            'confidence': 0.85,
            'position': {'x': 0.5, 'y': 0.4},
          },
          {
            'label': '1 B',
            'confidence': 0.72,
            'position': {'x': 0.3, 'y': 0.6},
          },
        ];

        // Process recognitions to get AR models
        final processedModels = <String, ARModel>{};
        
        for (final recognition in recognitions) {
          final label = recognition['label'] as String;
          final letterLabel = _extractLetterFromLabel(label);
          final confidence = recognition['confidence'] as double;
          
          if (letterLabel.isNotEmpty && confidence > 0.65) {
            final model = modelMapping.getModelForLetter(letterLabel);
            if (model != null) {
              processedModels[letterLabel] = model;
            }
          }
        }

        expect(processedModels.length, equals(2));
        expect(processedModels.containsKey('A'), isTrue);
        expect(processedModels.containsKey('B'), isTrue);
        expect(processedModels['A']!.name, equals('Apple'));
        expect(processedModels['B']!.name, equals('Ball'));
      });

      test('should filter low confidence detections', () async {
        final recognitions = [
          {
            'label': '0 A',
            'confidence': 0.85, // High confidence - should be included
            'position': {'x': 0.5, 'y': 0.4},
          },
          {
            'label': '1 B',
            'confidence': 0.45, // Low confidence - should be filtered out
            'position': {'x': 0.3, 'y': 0.6},
          },
        ];

        final processedModels = <String, ARModel>{};
        
        for (final recognition in recognitions) {
          final label = recognition['label'] as String;
          final letterLabel = _extractLetterFromLabel(label);
          final confidence = recognition['confidence'] as double;
          
          if (letterLabel.isNotEmpty && confidence > 0.65) {
            final model = modelMapping.getModelForLetter(letterLabel);
            if (model != null) {
              processedModels[letterLabel] = model;
            }
          }
        }

        expect(processedModels.length, equals(1));
        expect(processedModels.containsKey('A'), isTrue);
        expect(processedModels.containsKey('B'), isFalse);
      });

      test('should handle position mapping from detection to AR space', () async {
        final recognition = {
          'label': '0 A',
          'confidence': 0.85,
          'position': {'x': 0.7, 'y': 0.3}, // Top-right of screen
        };

        // Convert screen position to AR space position
        final screenPos = recognition['position'] as Map<String, dynamic>;
        final normalizedX = (screenPos['x'] as double * 2) - 1.0; // 0.4
        final normalizedY = -((screenPos['y'] as double * 2) - 1.0); // 0.4
        
        final arPosition = Vector3(
          normalizedX * 1.5, // 0.6
          normalizedY * 0.5 - 0.3, // -0.1
          -2.0,
        );

        expect(arPosition.x, closeTo(0.6, 0.1));
        expect(arPosition.y, closeTo(-0.1, 0.1));
        expect(arPosition.z, equals(-2.0));
      });
    });

    group('AR Model Placement Integration', () {
      test('should place model in AR scene based on detection', () async {
        await arManager.startSession();
        
        final recognition = {
          'label': '0 A',
          'confidence': 0.85,
          'position': {'x': 0.5, 'y': 0.4},
        };

        final letterLabel = _extractLetterFromLabel(recognition['label'] as String);
        final model = modelMapping.getModelForLetter(letterLabel);
        
        expect(model, isNotNull);

        // Get the model node from model manager
        final node = await modelManager.getModel(model!.id);
        expect(node, isNotNull);

        // Place model in AR scene
        final position = Vector3(0, -0.5, -2.0);
        final arNode = await arManager.addModelToScene(
          id: letterLabel,
          modelPath: node!.modelPath,
          position: position,
          scale: model.scale,
        );

        expect(arNode, isNotNull);
        expect(arManager.activeNodes.containsKey(letterLabel), isTrue);
        expect(arManager.activeNodes[letterLabel]!.position, equals(position));
      });

      test('should update model position when detection moves', () async {
        await arManager.startSession();
        
        final letterLabel = 'A';
        final model = modelMapping.getModelForLetter(letterLabel)!;
        final node = await modelManager.getModel(model.id);

        // Initial placement
        final initialPosition = Vector3(0, -0.5, -2.0);
        await arManager.addModelToScene(
          id: letterLabel,
          modelPath: node!.modelPath,
          position: initialPosition,
          scale: model.scale,
        );

        expect(arManager.activeNodes[letterLabel]!.position, equals(initialPosition));

        // Update position
        final newPosition = Vector3(0.5, -0.3, -2.0);
        await arManager.addModelToScene(
          id: letterLabel,
          modelPath: node.modelPath,
          position: newPosition,
          scale: model.scale,
        );

        expect(arManager.activeNodes[letterLabel]!.position, equals(newPosition));
      });

      test('should handle multiple simultaneous detections', () async {
        await arManager.startSession();
        
        final recognitions = [
          {'label': '0 A', 'confidence': 0.85, 'position': {'x': 0.3, 'y': 0.4}},
          {'label': '1 B', 'confidence': 0.78, 'position': {'x': 0.7, 'y': 0.6}},
          {'label': '2 C', 'confidence': 0.92, 'position': {'x': 0.5, 'y': 0.3}},
        ];

        final placedModels = <String, ARNode>{};

        for (final recognition in recognitions) {
          final letterLabel = _extractLetterFromLabel(recognition['label'] as String);
          final confidence = recognition['confidence'] as double;
          
          if (confidence > 0.65) {
            final model = modelMapping.getModelForLetter(letterLabel);
            if (model != null) {
              final node = await modelManager.getModel(model.id);
              if (node != null) {
                final position = Vector3(0, -0.5, -2.0); // Simplified positioning
                final arNode = await arManager.addModelToScene(
                  id: letterLabel,
                  modelPath: node.modelPath,
                  position: position,
                  scale: model.scale,
                );
                if (arNode != null) {
                  placedModels[letterLabel] = arNode;
                }
              }
            }
          }
        }

        expect(placedModels.length, equals(3));
        expect(placedModels.containsKey('A'), isTrue);
        expect(placedModels.containsKey('B'), isTrue);
        expect(placedModels.containsKey('C'), isTrue);
        expect(arManager.activeNodes.length, equals(3));
      });
    });

    group('Model Loading and Caching Integration', () {
      test('should efficiently load and cache models during AR session', () async {
        await arManager.startSession();
        
        final initialCacheSize = modelManager.cacheSize;
        
        // Load multiple models
        final letters = ['A', 'B', 'C'];
        final loadedNodes = <String, ARNode>{};

        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          if (node != null) {
            loadedNodes[letter] = node;
          }
        }

        expect(loadedNodes.length, equals(3));
        expect(modelManager.cacheSize, equals(initialCacheSize + 3));

        // Load same models again - should use cache
        final cachedNodes = <String, ARNode>{};
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          if (node != null) {
            cachedNodes[letter] = node;
          }
        }

        expect(cachedNodes.length, equals(3));
        expect(modelManager.cacheSize, equals(initialCacheSize + 3)); // No increase
      });

      test('should handle model loading failures gracefully', () async {
        await arManager.startSession();
        
        // Try to load a non-existent model
        final node = await modelManager.getModel('non_existent_model');
        expect(node, isNull);

        // AR session should still be functional
        expect(arManager.isSessionActive, isTrue);
        
        // Should still be able to load valid models
        final validModel = modelMapping.getModelForLetter('A')!;
        final validNode = await modelManager.getModel(validModel.id);
        expect(validNode, isNotNull);
      });
    });

    group('Performance Integration', () {
      test('should maintain performance with multiple models', () async {
        await arManager.startSession();
        
        final startTime = DateTime.now();
        
        // Load and place multiple models
        final letters = ['A', 'B', 'C', 'D', 'E'];
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          if (node != null) {
            await arManager.addModelToScene(
              id: letter,
              modelPath: node.modelPath,
              position: Vector3(0, -0.5, -2.0),
              scale: model.scale,
            );
          }
        }
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        // Should complete within reasonable time (5 seconds)
        expect(duration.inSeconds, lessThan(5));
        expect(arManager.activeNodes.length, equals(5));
      });

      test('should handle memory pressure by trimming cache', () async {
        // Load many models to trigger cache trimming
        final letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
        
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter);
          if (model != null) {
            await modelManager.getModel(model.id);
          }
        }

        // Cache should be trimmed to reasonable size
        expect(modelManager.cacheSize, lessThanOrEqualTo(10));
        expect(modelManager.estimatedMemoryUsageBytes, greaterThan(0));
      });
    });

    group('Error Handling Integration', () {
      test('should handle AR initialization failure gracefully', () async {
        // Dispose current manager to simulate failure
        arManager.dispose();
        
        // Try to use AR features
        final result = await arManager.startSession();
        expect(result, isFalse);
        
        // Should not crash when trying to add models
        final node = await arManager.addModelToScene(
          id: 'test',
          modelPath: 'test/path',
          position: Vector3(0, 0, 0),
        );
        expect(node, isNull);
      });

      test('should recover from temporary AR failures', () async {
        await arManager.initialize();
        await arManager.startSession();
        
        // Simulate session pause
        await arManager.pauseSession();
        expect(arManager.isSessionPaused, isTrue);
        
        // Should be able to resume
        final resumeResult = await arManager.resumeSession();
        expect(resumeResult, isTrue);
        expect(arManager.isSessionPaused, isFalse);
        
        // Should still be able to add models
        final model = modelMapping.getModelForLetter('A')!;
        final node = await modelManager.getModel(model.id);
        final arNode = await arManager.addModelToScene(
          id: 'A',
          modelPath: node!.modelPath,
          position: Vector3(0, -0.5, -2.0),
          scale: model.scale,
        );
        
        expect(arNode, isNotNull);
      });
    });

    group('User Interaction Integration', () {
      test('should handle hit testing for model selection', () async {
        await arManager.startSession();
        
        // Place a model in the scene
        final model = modelMapping.getModelForLetter('A')!;
        final node = await modelManager.getModel(model.id);
        await arManager.addModelToScene(
          id: 'A',
          modelPath: node!.modelPath,
          position: Vector3(0, -0.5, -2.0),
          scale: model.scale,
        );

        // Simulate tap in center of screen
        const tapPosition = Offset(200, 300);
        const screenSize = Size(400, 600);
        
        final hitModelId = await arManager.performHitTest(tapPosition, screenSize);
        expect(hitModelId, equals('A'));
      });

      test('should handle model transformation gestures', () async {
        await arManager.startSession();
        
        // Place a model
        final model = modelMapping.getModelForLetter('A')!;
        final node = await modelManager.getModel(model.id);
        await arManager.addModelToScene(
          id: 'A',
          modelPath: node!.modelPath,
          position: Vector3(0, -0.5, -2.0),
          scale: model.scale,
        );

        // Simulate scale transformation
        final newScale = model.scale * 1.5;
        await arManager.addModelToScene(
          id: 'A',
          modelPath: node.modelPath,
          position: Vector3(0, -0.5, -2.0),
          scale: newScale,
        );

        final updatedNode = arManager.activeNodes['A'];
        expect(updatedNode, isNotNull);
        expect(updatedNode!.scale.x, closeTo(newScale, 0.01));
      });
    });

    group('Real-time Updates Integration', () {
      test('should handle rapid detection updates', () async {
        await arManager.startSession();
        
        // Simulate rapid detection updates
        final detectionSequence = [
          {'label': '0 A', 'confidence': 0.85, 'position': {'x': 0.5, 'y': 0.4}},
          {'label': '0 A', 'confidence': 0.87, 'position': {'x': 0.52, 'y': 0.41}},
          {'label': '0 A', 'confidence': 0.83, 'position': {'x': 0.48, 'y': 0.39}},
          {'label': '1 B', 'confidence': 0.78, 'position': {'x': 0.3, 'y': 0.6}},
        ];

        String? currentModelId;
        
        for (final detection in detectionSequence) {
          final letterLabel = _extractLetterFromLabel(detection['label'] as String);
          final confidence = detection['confidence'] as double;
          
          if (confidence > 0.65) {
            final model = modelMapping.getModelForLetter(letterLabel);
            if (model != null) {
              final node = await modelManager.getModel(model.id);
              if (node != null) {
                await arManager.addModelToScene(
                  id: letterLabel,
                  modelPath: node.modelPath,
                  position: Vector3(0, -0.5, -2.0),
                  scale: model.scale,
                );
                currentModelId = letterLabel;
              }
            }
          }
        }

        expect(currentModelId, equals('B')); // Last valid detection
        expect(arManager.activeNodes.containsKey('A'), isTrue);
        expect(arManager.activeNodes.containsKey('B'), isTrue);
      });

      test('should clean up models when detection is lost', () async {
        await arManager.startSession();
        
        // Place a model
        final model = modelMapping.getModelForLetter('A')!;
        final node = await modelManager.getModel(model.id);
        await arManager.addModelToScene(
          id: 'A',
          modelPath: node!.modelPath,
          position: Vector3(0, -0.5, -2.0),
          scale: model.scale,
        );

        expect(arManager.activeNodes.containsKey('A'), isTrue);

        // Simulate detection loss by removing the model
        final removeResult = await arManager.removeNode('A');
        expect(removeResult, isTrue);
        expect(arManager.activeNodes.containsKey('A'), isFalse);
      });
    });
  });
}

/// Helper function to extract letter from label string
String _extractLetterFromLabel(String label) {
  final parts = label.split(' ');
  if (parts.length > 1) {
    return parts[1];
  }
  return '';
}