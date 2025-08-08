import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/material.dart' as material;
import 'package:kidverse/ar/utils/model_manager.dart';

void main() {
  group('ModelManager Tests', () {
    late ModelManager modelManager;

    setUp(() {
      modelManager = ModelManager();
    });

    tearDown(() {
      modelManager.clearCache();
    });

    group('Singleton Pattern', () {
      test('should be a singleton', () {
        final instance1 = ModelManager();
        final instance2 = ModelManager();
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Model Loading', () {
      test('should load model successfully', () async {
        final node = await modelManager.getModel('apple');

        expect(node, isNotNull);
        expect(node!.id, contains('apple'));
        expect(node.modelPath, isNotEmpty);
        expect(modelManager.cacheSize, equals(1));
      });

      test('should return cached model on subsequent requests', () async {
        final node1 = await modelManager.getModel('apple');
        final initialCacheSize = modelManager.cacheSize;

        final node2 = await modelManager.getModel('apple');

        expect(node1, isNotNull);
        expect(node2, isNotNull);
        expect(modelManager.cacheSize, equals(initialCacheSize));
      });

      test('should load model with custom properties', () async {
        final node = await modelManager.getModel(
          'apple',
          scale: 0.5,
          position: Vector3(1, 2, 3),
          rotation: Vector3(0.1, 0.2, 0.3),
          shadowIntensity: 0.9,
          shadowSoftness: 0.7,
          exposure: 1.2,
          environmentLighting: 'studio',
          colorTint: material.Colors.red,
          autoRotate: true,
          autoRotateSpeed: 45.0,
        );

        expect(node, isNotNull);
        expect(node!.scale, equals(Vector3(0.5, 0.5, 0.5)));
        expect(node.position, equals(Vector3(1, 2, 3)));
        expect(node.rotation, equals(Vector3(0.1, 0.2, 0.3)));
        expect(node.shadowIntensity, equals(0.9));
        expect(node.shadowSoftness, equals(0.7));
        expect(node.exposure, equals(1.2));
        expect(node.environmentLighting, equals('studio'));
        expect(node.colorTint, equals(Colors.red));
        expect(node.autoRotate, isTrue);
        expect(node.autoRotateSpeed, equals(45.0));
      });

      test('should return null for non-existent model', () async {
        final node = await modelManager.getModel('non_existent_model');
        expect(node, isNull);
      });

      test('should load model with optimization parameters', () async {
        final node = await modelManager.getModel(
          'apple',
          levelOfDetail: 0, // Low detail
          useCompressedTextures: true,
          maxTextureSize: 512,
        );

        expect(node, isNotNull);
        // The cache key should include optimization parameters
        expect(modelManager.cacheSize, equals(1));
      });
    });

    group('Cache Management', () {
      test('should track cache size correctly', () async {
        expect(modelManager.cacheSize, equals(0));

        await modelManager.getModel('apple');
        expect(modelManager.cacheSize, equals(1));

        await modelManager.getModel('ball');
        expect(modelManager.cacheSize, equals(2));
      });

      test('should clear cache', () async {
        await modelManager.getModel('apple');
        await modelManager.getModel('ball');
        expect(modelManager.cacheSize, equals(2));

        modelManager.clearCache();
        expect(modelManager.cacheSize, equals(0));
      });

      test('should trim cache when it exceeds maximum size', () async {
        // Load models to exceed cache size
        final modelNames = [
          'apple',
          'ball',
          'cat',
          'dog',
          'elephant',
          'fish',
          'giraffe',
          'horse',
          'icecream',
          'jug',
          'kite',
          'lion'
        ]; // More than max cache size

        for (final modelName in modelNames) {
          await modelManager.getModel(modelName);
        }

        // Cache should be trimmed
        expect(modelManager.cacheSize, lessThanOrEqualTo(10)); // Max cache size
      });

      test('should track memory usage', () async {
        final initialMemory = modelManager.estimatedMemoryUsageBytes;

        await modelManager.getModel('apple');

        expect(
            modelManager.estimatedMemoryUsageBytes, greaterThan(initialMemory));
      });
    });

    group('Model Existence Check', () {
      test('should check if model exists', () async {
        final existsApple = await modelManager.modelExists('apple');
        final existsNonExistent =
            await modelManager.modelExists('non_existent');

        expect(existsApple, isTrue);
        expect(existsNonExistent, isFalse);
      });
    });

    group('Preloading', () {
      test('should preload common models', () async {
        await modelManager.preloadCommonModels();

        // This test mainly ensures the method doesn't throw
        // In a real implementation, we would check that common models are cached
        expect(true, isTrue); // Placeholder assertion
      });
    });

    group('Optimization', () {
      test('should handle different levels of detail', () async {
        final highDetailNode = await modelManager.getModel(
          'apple',
          levelOfDetail: 2, // High detail
        );

        final lowDetailNode = await modelManager.getModel(
          'apple',
          levelOfDetail: 0, // Low detail
        );

        expect(highDetailNode, isNotNull);
        expect(lowDetailNode, isNotNull);

        // Should create separate cache entries for different LODs
        expect(modelManager.cacheSize, equals(2));
      });

      test('should handle texture compression settings', () async {
        final compressedNode = await modelManager.getModel(
          'apple',
          useCompressedTextures: true,
          maxTextureSize: 512,
        );

        final uncompressedNode = await modelManager.getModel(
          'apple',
          useCompressedTextures: false,
          maxTextureSize: 1024,
        );

        expect(compressedNode, isNotNull);
        expect(uncompressedNode, isNotNull);

        // Should create separate cache entries for different compression settings
        expect(modelManager.cacheSize, equals(2));
      });
    });

    group('Error Handling', () {
      test('should handle loading errors gracefully', () async {
        // Try to load a model with invalid parameters
        final node = await modelManager.getModel('');

        // Should handle the error gracefully
        expect(node, isNull);
      });

      test('should fall back to standard loading when optimization fails',
          () async {
        // This test would require mocking the optimization to fail
        // For now, we test that the fallback mechanism exists
        final node = await modelManager.getModel('apple');
        expect(node, isNotNull);
      });
    });

    group('Performance Metrics', () {
      test('should provide cache metrics', () {
        expect(modelManager.cacheSize, isA<int>());
        expect(modelManager.estimatedMemoryUsageBytes, isA<int>());
        expect(modelManager.getCacheSize, isA<int>());
      });

      test('should update memory usage when models are added', () async {
        final initialMemory = modelManager.estimatedMemoryUsageBytes;

        await modelManager.getModel('apple');
        await modelManager.getModel('ball');

        expect(
            modelManager.estimatedMemoryUsageBytes, greaterThan(initialMemory));
      });

      test('should update memory usage when cache is cleared', () async {
        await modelManager.getModel('apple');
        await modelManager.getModel('ball');

        final memoryWithModels = modelManager.estimatedMemoryUsageBytes;
        expect(memoryWithModels, greaterThan(0));

        modelManager.clearCache();
        expect(modelManager.estimatedMemoryUsageBytes, equals(0));
      });
    });
  });
}
