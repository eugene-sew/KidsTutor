import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as material show Colors;
import 'package:kidverse/ar/utils/ar_manager.dart';

void main() {
  group('ARManager Tests', () {
    late ARManager arManager;

    setUp(() {
      arManager = ARManager();
    });

    tearDown(() {
      arManager.dispose();
    });

    group('Initialization', () {
      test('should be a singleton', () {
        final instance1 = ARManager();
        final instance2 = ARManager();
        expect(identical(instance1, instance2), isTrue);
      });

      test('should initialize successfully', () async {
        final result = await arManager.initialize();
        expect(result, isTrue);
        expect(arManager.isInitialized, isTrue);
        expect(arManager.isARSupported, isTrue);
      });

      test('should return same result on multiple initializations', () async {
        final result1 = await arManager.initialize();
        final result2 = await arManager.initialize();
        expect(result1, equals(result2));
        expect(arManager.isInitialized, isTrue);
      });
    });

    group('Session Management', () {
      setUp(() async {
        await arManager.initialize();
      });

      test('should start session successfully when initialized', () async {
        final result = await arManager.startSession();
        expect(result, isTrue);
        expect(arManager.isSessionActive, isTrue);
        expect(arManager.isSessionPaused, isFalse);
      });

      test('should not start session when not initialized', () async {
        final uninitializedManager = ARManager();
        uninitializedManager.dispose(); // Reset state
        final result = await uninitializedManager.startSession();
        expect(result, isFalse);
        expect(uninitializedManager.isSessionActive, isFalse);
      });

      test('should pause and resume session', () async {
        await arManager.startSession();

        final pauseResult = await arManager.pauseSession();
        expect(pauseResult, isTrue);
        expect(arManager.isSessionPaused, isTrue);
        expect(arManager.isSessionActive, isTrue);

        final resumeResult = await arManager.resumeSession();
        expect(resumeResult, isTrue);
        expect(arManager.isSessionPaused, isFalse);
        expect(arManager.isSessionActive, isTrue);
      });

      test('should stop session successfully', () async {
        await arManager.startSession();

        final result = await arManager.stopSession();
        expect(result, isTrue);
        expect(arManager.isSessionActive, isFalse);
        expect(arManager.isSessionPaused, isFalse);
      });

      test('should not pause session when not active', () async {
        final result = await arManager.pauseSession();
        expect(result, isFalse);
      });

      test('should not resume session when not paused', () async {
        await arManager.startSession();
        final result = await arManager.resumeSession();
        expect(result, isFalse);
      });
    });

    group('Model Management', () {
      setUp(() async {
        await arManager.initialize();
      });

      test('should add model to scene successfully', () async {
        final position = Vector3(1.0, 0.0, -2.0);
        final node = await arManager.addModelToScene(
          id: 'test_model',
          modelPath: 'assets/3d_models/apple.glb',
          position: position,
          scale: 0.5,
        );

        expect(node, isNotNull);
        expect(node!.id, equals('test_model'));
        expect(node.position, equals(position));
        expect(node.scale, equals(Vector3(0.5, 0.5, 0.5)));
        expect(arManager.activeNodes.containsKey('test_model'), isTrue);
      });

      test('should not add model when not initialized', () async {
        final uninitializedManager = ARManager();
        uninitializedManager.dispose(); // Reset state

        final node = await uninitializedManager.addModelToScene(
          id: 'test_model',
          modelPath: 'assets/3d_models/apple.glb',
          position: Vector3(0, 0, 0),
        );

        expect(node, isNull);
      });

      test('should add model with enhanced rendering properties', () async {
        final node = await arManager.addModelToScene(
          id: 'enhanced_model',
          modelPath: 'assets/3d_models/apple.glb',
          position: Vector3(0, 0, -1),
          shadowIntensity: 0.9,
          shadowSoftness: 0.7,
          exposure: 1.2,
          environmentLighting: 'studio',
          colorTint: material.Colors.red,
          autoRotate: true,
          autoRotateSpeed: 45.0,
        );

        expect(node, isNotNull);
        expect(node!.shadowIntensity, equals(0.9));
        expect(node.shadowSoftness, equals(0.7));
        expect(node.exposure, equals(1.2));
        expect(node.environmentLighting, equals('studio'));
        expect(node.colorTint, equals(material.Colors.red));
        expect(node.autoRotate, isTrue);
        expect(node.autoRotateSpeed, equals(45.0));
      });

      test('should remove node from scene', () async {
        await arManager.addModelToScene(
          id: 'removable_model',
          modelPath: 'assets/3d_models/apple.glb',
          position: Vector3(0, 0, 0),
        );

        expect(arManager.activeNodes.containsKey('removable_model'), isTrue);

        final result = await arManager.removeNode('removable_model');
        expect(result, isTrue);
        expect(arManager.activeNodes.containsKey('removable_model'), isFalse);
      });

      test('should return false when removing non-existent node', () async {
        final result = await arManager.removeNode('non_existent');
        expect(result, isFalse);
      });

      test('should clear all nodes from scene', () async {
        await arManager.addModelToScene(
          id: 'model1',
          modelPath: 'assets/3d_models/apple.glb',
          position: Vector3(0, 0, 0),
        );
        await arManager.addModelToScene(
          id: 'model2',
          modelPath: 'assets/3d_models/ball.glb',
          position: Vector3(1, 0, 0),
        );

        expect(arManager.activeNodes.length, equals(2));

        await arManager.clearScene();
        expect(arManager.activeNodes.length, equals(0));
      });
    });

    group('Hit Testing', () {
      setUp(() async {
        await arManager.initialize();
        await arManager.startSession();
      });

      test('should perform hit test successfully', () async {
        await arManager.addModelToScene(
          id: 'hittable_model',
          modelPath: 'assets/3d_models/apple.glb',
          position: Vector3(0, 0, -1),
        );

        final tapPosition = const Offset(200, 300);
        const screenSize = Size(400, 600);

        final hitNodeId =
            await arManager.performHitTest(tapPosition, screenSize);
        expect(hitNodeId, equals('hittable_model'));
      });

      test('should return null when no model is hit', () async {
        const tapPosition = Offset(50, 50); // Far from center
        const screenSize = Size(400, 600);

        final hitNodeId =
            await arManager.performHitTest(tapPosition, screenSize);
        expect(hitNodeId, isNull);
      });

      test('should not perform hit test when session is not active', () async {
        await arManager.stopSession();

        const tapPosition = Offset(200, 300);
        const screenSize = Size(400, 600);

        final hitNodeId =
            await arManager.performHitTest(tapPosition, screenSize);
        expect(hitNodeId, isNull);
      });

      test('should not perform hit test when session is paused', () async {
        await arManager.pauseSession();

        const tapPosition = Offset(200, 300);
        const screenSize = Size(400, 600);

        final hitNodeId =
            await arManager.performHitTest(tapPosition, screenSize);
        expect(hitNodeId, isNull);
      });
    });

    group('Performance Monitoring', () {
      setUp(() async {
        await arManager.initialize();
      });

      test('should track performance metrics', () async {
        await arManager.startSession();

        // Performance metrics should be initialized
        expect(arManager.currentFPS, equals(0.0));
        expect(arManager.memoryUsageBytes, equals(0));
      });

      test('should estimate memory usage based on active nodes', () async {
        await arManager.startSession();

        await arManager.addModelToScene(
          id: 'memory_test_model',
          modelPath: 'assets/3d_models/apple.glb',
          position: Vector3(0, 0, 0),
        );

        // Memory usage should increase with active nodes
        expect(arManager.memoryUsageBytes, greaterThan(0));
      });

      test('should reduce resource usage when needed', () async {
        await arManager.startSession();

        // Add multiple models to trigger resource reduction
        for (int i = 0; i < 5; i++) {
          await arManager.addModelToScene(
            id: 'model_$i',
            modelPath: 'assets/3d_models/apple.glb',
            position: Vector3(i.toDouble(), 0, 0),
          );
        }

        final initialNodeCount = arManager.activeNodes.length;
        await arManager.reduceResourceUsage();

        // Should have removed at least one node
        expect(arManager.activeNodes.length, lessThan(initialNodeCount));
      });
    });

    group('Error Handling', () {
      test('should handle initialization errors gracefully', () async {
        // This test would require mocking the AR availability check to fail
        // For now, we test that the error handler is accessible
        expect(arManager.errorHandler, isNotNull);
      });

      test('should handle model addition errors gracefully', () async {
        await arManager.initialize();

        // Try to add a model with invalid parameters
        final node = await arManager.addModelToScene(
          id: '',
          modelPath: '',
          position: Vector3(0, 0, 0),
        );

        // Should handle the error and return null
        expect(node, isNull);
      });
    });

    group('Disposal', () {
      test('should dispose resources properly', () async {
        await arManager.initialize();
        await arManager.startSession();
        await arManager.addModelToScene(
          id: 'disposable_model',
          modelPath: 'assets/3d_models/apple.glb',
          position: Vector3(0, 0, 0),
        );

        arManager.dispose();

        expect(arManager.isSessionActive, isFalse);
        expect(arManager.activeNodes.length, equals(0));
      });
    });
  });
}
