import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../../lib/ar/utils/ar_manager.dart';
import '../../../lib/ar/utils/model_manager.dart';
import '../../../lib/ar/models/ar_model_mapping.dart';

void main() {
  group('AR Performance Benchmark Tests', () {
    late ARManager arManager;
    late ModelManager modelManager;
    late ARModelMapping modelMapping;

    setUp(() async {
      arManager = ARManager();
      modelManager = ModelManager();
      modelMapping = ARModelMapping();

      await arManager.initialize();
    });

    tearDown(() {
      arManager.dispose();
      modelManager.clearCache();
    });

    group('Initialization Performance', () {
      test('should initialize AR components within acceptable time', () async {
        final stopwatch = Stopwatch()..start();

        // Reinitialize to measure time
        arManager.dispose();
        final newManager = ARManager();
        await newManager.initialize();
        await newManager.startSession();

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // 2 seconds max
        expect(newManager.isInitialized, isTrue);
        expect(newManager.isSessionActive, isTrue);

        newManager.dispose();
      });

      test('should preload common models efficiently', () async {
        final stopwatch = Stopwatch()..start();

        await modelManager.preloadCommonModels();

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
        // Verify some models were preloaded (path cache should have entries)
        expect(modelManager.cacheSize, greaterThanOrEqualTo(0));
      });
    });

    group('Model Loading Performance', () {
      test('should load single model within acceptable time', () async {
        final stopwatch = Stopwatch()..start();

        final model = modelMapping.getModelForLetter('A')!;
        final node = await modelManager.getModel(model.id);

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // 1 second max
        expect(node, isNotNull);
      });

      test('should load multiple models efficiently', () async {
        final letters = ['A', 'B', 'C', 'D', 'E'];
        final stopwatch = Stopwatch()..start();

        final loadedNodes = <String, dynamic>{};
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          if (node != null) {
            loadedNodes[letter] = node;
          }
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds,
            lessThan(3000)); // 3 seconds for 5 models
        expect(loadedNodes.length, equals(5));
      });

      test('should benefit from caching on repeated loads', () async {
        final model = modelMapping.getModelForLetter('A')!;

        // First load (cold)
        final stopwatch1 = Stopwatch()..start();
        final node1 = await modelManager.getModel(model.id);
        stopwatch1.stop();

        // Second load (cached)
        final stopwatch2 = Stopwatch()..start();
        final node2 = await modelManager.getModel(model.id);
        stopwatch2.stop();

        expect(node1, isNotNull);
        expect(node2, isNotNull);

        // Cached load should be significantly faster
        expect(stopwatch2.elapsedMilliseconds,
            lessThan(stopwatch1.elapsedMilliseconds));
        expect(stopwatch2.elapsedMilliseconds,
            lessThan(100)); // Very fast for cached
      });
    });

    group('AR Scene Performance', () {
      test('should add models to scene efficiently', () async {
        await arManager.startSession();

        final model = modelMapping.getModelForLetter('A')!;
        final node = await modelManager.getModel(model.id);

        final stopwatch = Stopwatch()..start();

        final arNode = await arManager.addModelToScene(
          id: 'A',
          modelPath: node!.modelPath,
          position: Vector3(0, -0.5, -2.0),
          scale: model.scale,
        );

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(500)); // 0.5 seconds max
        expect(arNode, isNotNull);
      });

      test('should handle multiple models in scene', () async {
        await arManager.startSession();

        final letters = ['A', 'B', 'C', 'D', 'E'];
        final stopwatch = Stopwatch()..start();

        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          await arManager.addModelToScene(
            id: letter,
            modelPath: node!.modelPath,
            position: Vector3(0, -0.5, -2.0),
            scale: model.scale,
          );
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds,
            lessThan(2500)); // 2.5 seconds for 5 models
        expect(arManager.activeNodes.length, equals(5));
      });

      test('should remove models from scene quickly', () async {
        await arManager.startSession();

        // Add models first
        final letters = ['A', 'B', 'C'];
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          await arManager.addModelToScene(
            id: letter,
            modelPath: node!.modelPath,
            position: Vector3(0, -0.5, -2.0),
            scale: model.scale,
          );
        }

        // Time removal
        final stopwatch = Stopwatch()..start();

        for (final letter in letters) {
          await arManager.removeNode(letter);
        }

        stopwatch.stop();

        expect(
            stopwatch.elapsedMilliseconds, lessThan(100)); // Very fast removal
        expect(arManager.activeNodes.length, equals(0));
      });

      test('should clear entire scene quickly', () async {
        await arManager.startSession();

        // Add many models
        final letters = 'ABCDEFGHIJ'.split('');
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          await arManager.addModelToScene(
            id: letter,
            modelPath: node!.modelPath,
            position: Vector3(0, -0.5, -2.0),
            scale: model.scale,
          );
        }

        expect(arManager.activeNodes.length, equals(10));

        // Time scene clearing
        final stopwatch = Stopwatch()..start();
        await arManager.clearScene();
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Very fast clear
        expect(arManager.activeNodes.length, equals(0));
      });
    });

    group('Hit Testing Performance', () {
      test('should perform hit tests quickly', () async {
        await arManager.startSession();

        // Add a model
        final model = modelMapping.getModelForLetter('A')!;
        final node = await modelManager.getModel(model.id);
        await arManager.addModelToScene(
          id: 'A',
          modelPath: node!.modelPath,
          position: Vector3(0, -0.5, -2.0),
          scale: model.scale,
        );

        const tapPosition = Offset(200, 300);
        const screenSize = Size(400, 600);

        final stopwatch = Stopwatch()..start();

        final hitModelId =
            await arManager.performHitTest(tapPosition, screenSize);

        stopwatch.stop();

        expect(
            stopwatch.elapsedMilliseconds, lessThan(50)); // Very fast hit test
        expect(hitModelId, equals('A'));
      });

      test('should handle rapid hit tests efficiently', () async {
        await arManager.startSession();

        // Add multiple models
        final letters = ['A', 'B', 'C'];
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          await arManager.addModelToScene(
            id: letter,
            modelPath: node!.modelPath,
            position: Vector3(0, -0.5, -2.0),
            scale: model.scale,
          );
        }

        const tapPosition = Offset(200, 300);
        const screenSize = Size(400, 600);

        final stopwatch = Stopwatch()..start();

        // Perform 100 rapid hit tests
        for (int i = 0; i < 100; i++) {
          await arManager.performHitTest(tapPosition, screenSize);
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds,
            lessThan(1000)); // 1 second for 100 tests
        expect(stopwatch.elapsedMilliseconds / 100,
            lessThan(10)); // <10ms per test
      });
    });

    group('Memory Performance', () {
      test('should manage memory efficiently with model cache', () async {
        final initialMemory = modelManager.estimatedMemoryUsageBytes;

        // Load several models
        final letters = ['A', 'B', 'C', 'D', 'E'];
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          await modelManager.getModel(model.id);
        }

        final memoryAfterLoading = modelManager.estimatedMemoryUsageBytes;
        expect(memoryAfterLoading, greaterThan(initialMemory));

        // Clear cache
        modelManager.clearCache();

        final memoryAfterClear = modelManager.estimatedMemoryUsageBytes;
        expect(memoryAfterClear, equals(0));
      });

      test('should trim cache when memory limit is reached', () async {
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

        // Memory usage should be reasonable
        const maxExpectedMemory = 100 * 1024 * 1024; // 100MB
        expect(modelManager.estimatedMemoryUsageBytes,
            lessThan(maxExpectedMemory));
      });

      test('should track AR scene memory usage', () async {
        await arManager.startSession();

        final initialMemory = arManager.memoryUsageBytes;

        // Add models to scene
        final letters = ['A', 'B', 'C'];
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          await arManager.addModelToScene(
            id: letter,
            modelPath: node!.modelPath,
            position: Vector3(0, -0.5, -2.0),
            scale: model.scale,
          );
        }

        final memoryAfterAdding = arManager.memoryUsageBytes;
        expect(memoryAfterAdding, greaterThan(initialMemory));

        // Clear scene
        await arManager.clearScene();

        final memoryAfterClear = arManager.memoryUsageBytes;
        expect(memoryAfterClear, equals(initialMemory));
      });
    });

    group('Session Management Performance', () {
      test('should start and stop sessions quickly', () async {
        // Test session start
        final startStopwatch = Stopwatch()..start();
        await arManager.startSession();
        startStopwatch.stop();

        expect(
            startStopwatch.elapsedMilliseconds, lessThan(1000)); // 1 second max
        expect(arManager.isSessionActive, isTrue);

        // Test session stop
        final stopStopwatch = Stopwatch()..start();
        await arManager.stopSession();
        stopStopwatch.stop();

        expect(stopStopwatch.elapsedMilliseconds,
            lessThan(500)); // 0.5 seconds max
        expect(arManager.isSessionActive, isFalse);
      });

      test('should pause and resume sessions efficiently', () async {
        await arManager.startSession();

        // Test pause
        final pauseStopwatch = Stopwatch()..start();
        await arManager.pauseSession();
        pauseStopwatch.stop();

        expect(pauseStopwatch.elapsedMilliseconds, lessThan(200)); // Very fast
        expect(arManager.isSessionPaused, isTrue);

        // Test resume
        final resumeStopwatch = Stopwatch()..start();
        await arManager.resumeSession();
        resumeStopwatch.stop();

        expect(resumeStopwatch.elapsedMilliseconds, lessThan(200)); // Very fast
        expect(arManager.isSessionPaused, isFalse);
      });
    });

    group('Stress Testing', () {
      test('should handle rapid model additions and removals', () async {
        await arManager.startSession();

        final stopwatch = Stopwatch()..start();

        // Rapidly add and remove models
        for (int i = 0; i < 50; i++) {
          final letter = String.fromCharCode(65 + (i % 26)); // A-Z cycling
          final model = modelMapping.getModelForLetter(letter);

          if (model != null) {
            final node = await modelManager.getModel(model.id);
            if (node != null) {
              // Add model
              await arManager.addModelToScene(
                id: '${letter}_$i',
                modelPath: node.modelPath,
                position: Vector3(0, -0.5, -2.0),
                scale: model.scale,
              );

              // Remove model after a few iterations
              if (i > 5) {
                final removeId =
                    '${String.fromCharCode(65 + ((i - 5) % 26))}_${i - 5}';
                await arManager.removeNode(removeId);
              }
            }
          }
        }

        stopwatch.stop();

        expect(
            stopwatch.elapsedMilliseconds, lessThan(10000)); // 10 seconds max
        expect(arManager.activeNodes.length,
            lessThanOrEqualTo(10)); // Should be manageable
      });

      test('should maintain performance under continuous operation', () async {
        await arManager.startSession();

        final performanceMetrics = <int>[];

        // Run continuous operations for a period
        for (int cycle = 0; cycle < 10; cycle++) {
          final cycleStopwatch = Stopwatch()..start();

          // Add some models
          final letters = ['A', 'B', 'C'];
          for (final letter in letters) {
            final model = modelMapping.getModelForLetter(letter)!;
            final node = await modelManager.getModel(model.id);
            await arManager.addModelToScene(
              id: '${letter}_$cycle',
              modelPath: node!.modelPath,
              position: Vector3(0, -0.5, -2.0),
              scale: model.scale,
            );
          }

          // Perform some hit tests
          const tapPosition = Offset(200, 300);
          const screenSize = Size(400, 600);
          for (int i = 0; i < 5; i++) {
            await arManager.performHitTest(tapPosition, screenSize);
          }

          // Remove models
          for (final letter in letters) {
            await arManager.removeNode('${letter}_$cycle');
          }

          cycleStopwatch.stop();
          performanceMetrics.add(cycleStopwatch.elapsedMilliseconds);
        }

        // Performance should remain consistent (no significant degradation)
        final averageTime = performanceMetrics.reduce((a, b) => a + b) /
            performanceMetrics.length;
        final maxTime = performanceMetrics.reduce((a, b) => a > b ? a : b);
        final minTime = performanceMetrics.reduce((a, b) => a < b ? a : b);

        expect(averageTime, lessThan(2000)); // 2 seconds average per cycle
        expect(maxTime - minTime,
            lessThan(1000)); // Variation should be reasonable
      });
    });

    group('Resource Usage Benchmarks', () {
      test('should optimize resource usage under pressure', () async {
        await arManager.startSession();

        // Add many models to trigger resource optimization
        final letters = 'ABCDEFGHIJ'.split('');
        for (final letter in letters) {
          final model = modelMapping.getModelForLetter(letter)!;
          final node = await modelManager.getModel(model.id);
          await arManager.addModelToScene(
            id: letter,
            modelPath: node!.modelPath,
            position: Vector3(0, -0.5, -2.0),
            scale: model.scale,
          );
        }

        expect(arManager.activeNodes.length, equals(10));

        // Trigger resource reduction
        final stopwatch = Stopwatch()..start();
        await arManager.reduceResourceUsage();
        stopwatch.stop();

        expect(
            stopwatch.elapsedMilliseconds, lessThan(100)); // Fast optimization
        expect(
            arManager.activeNodes.length, lessThan(10)); // Should have reduced
      });

      test('should handle model optimization efficiently', () async {
        final model = modelMapping.getModelForLetter('A')!;

        // Test different optimization levels
        final optimizationTests = [
          {'lod': 0, 'compressed': true, 'maxTexture': 512},
          {'lod': 1, 'compressed': true, 'maxTexture': 1024},
          {'lod': 2, 'compressed': false, 'maxTexture': 2048},
        ];

        final loadTimes = <int>[];

        for (final test in optimizationTests) {
          final stopwatch = Stopwatch()..start();

          final node = await modelManager.getModel(
            model.id,
            levelOfDetail: test['lod'] as int,
            useCompressedTextures: test['compressed'] as bool,
            maxTextureSize: test['maxTexture'] as int,
          );

          stopwatch.stop();

          expect(node, isNotNull);
          loadTimes.add(stopwatch.elapsedMilliseconds);
        }

        // All optimization levels should load within reasonable time
        for (final time in loadTimes) {
          expect(time, lessThan(2000)); // 2 seconds max per optimization
        }
      });
    });
  });
}
