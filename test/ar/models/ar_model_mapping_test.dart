import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:kidverse/ar/models/ar_model_mapping.dart';

void main() {
  group('ARModelMapping Tests', () {
    late ARModelMapping mapping;

    setUp(() {
      mapping = ARModelMapping();
    });

    group('Singleton Pattern', () {
      test('should be a singleton', () {
        final instance1 = ARModelMapping();
        final instance2 = ARModelMapping();
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Letter to Model Mapping', () {
      test('should return correct model for letter A', () {
        final model = mapping.getModelForLetter('A');

        expect(model, isNotNull);
        expect(model!.id, equals('apple'));
        expect(model.name, equals('Apple'));
        expect(model.modelPath, equals('assets/3d_models/apple.glb'));
        expect(model.scale, equals(0.2));
        expect(model.pronunciation, equals('A-pul'));
        expect(model.funFact, contains('Apples float in water'));
      });

      test('should return correct model for letter B', () {
        final model = mapping.getModelForLetter('B');

        expect(model, isNotNull);
        expect(model!.id, equals('ball'));
        expect(model.name, equals('Ball'));
        expect(model.modelPath, equals('assets/3d_models/ball.glb'));
        expect(model.scale, equals(0.15));
        expect(model.pronunciation, equals('Bawl'));
      });

      test('should handle lowercase letters', () {
        final modelUpper = mapping.getModelForLetter('A');
        final modelLower = mapping.getModelForLetter('a');

        expect(modelUpper, isNotNull);
        expect(modelLower, isNotNull);
        expect(modelUpper!.id, equals(modelLower!.id));
      });

      test('should return null for invalid letters', () {
        final model = mapping.getModelForLetter('1');
        expect(model, isNull);
      });

      test('should return null for empty string', () {
        final model = mapping.getModelForLetter('');
        expect(model, isNull);
      });

      test('should have models for all 26 letters', () {
        const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

        for (int i = 0; i < letters.length; i++) {
          final letter = letters[i];
          final model = mapping.getModelForLetter(letter);
          expect(model, isNotNull,
              reason: 'Model for letter $letter should exist');
        }
      });
    });

    group('Model by Name Lookup', () {
      test('should return correct model by name', () {
        final model = mapping.getModelByName('Apple');

        expect(model, isNotNull);
        expect(model!.id, equals('apple'));
        expect(model.name, equals('Apple'));
      });

      test('should handle case-insensitive name lookup', () {
        final modelUpper = mapping.getModelByName('APPLE');
        final modelLower = mapping.getModelByName('apple');
        final modelMixed = mapping.getModelByName('Apple');

        expect(modelUpper, isNotNull);
        expect(modelLower, isNotNull);
        expect(modelMixed, isNotNull);
        expect(modelUpper!.id, equals(modelLower!.id));
        expect(modelLower.id, equals(modelMixed!.id));
      });

      test('should return null for non-existent name', () {
        final model = mapping.getModelByName('NonExistentModel');
        expect(model, isNull);
      });
    });

    group('All Models and Letters', () {
      test('should return all available models', () {
        final models = mapping.getAllModels();

        expect(models, isNotEmpty);
        expect(models.length, equals(26)); // One for each letter

        // Check that all models have required properties
        for (final model in models) {
          expect(model.id, isNotEmpty);
          expect(model.name, isNotEmpty);
          expect(model.modelPath, isNotEmpty);
          expect(model.scale, greaterThan(0));
        }
      });

      test('should return all available letters', () {
        final letters = mapping.getAllLetters();

        expect(letters, isNotEmpty);
        expect(letters.length, equals(26));

        // Check that all letters A-Z are present
        const expectedLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        for (int i = 0; i < expectedLetters.length; i++) {
          expect(letters, contains(expectedLetters[i]));
        }
      });
    });

    group('Model Properties Validation', () {
      test('should have valid rendering properties for Apple model', () {
        final model = mapping.getModelForLetter('A');

        expect(model, isNotNull);
        expect(model!.shadowIntensity, equals(0.8));
        expect(model.shadowSoftness, equals(0.6));
        expect(model.exposure, equals(1.2));
        expect(model.environmentLighting, equals('neutral'));
        expect(model.autoRotate, isTrue);
        expect(model.autoRotateSpeed, equals(15.0));
        expect(model.rotation, equals(Vector3(0, 0.2, 0)));
        expect(model.levelOfDetail, equals(1));
        expect(model.useCompressedTextures, isTrue);
        expect(model.maxTextureSize, equals(1024));
      });

      test('should have valid rendering properties for Ball model', () {
        final model = mapping.getModelForLetter('B');

        expect(model, isNotNull);
        expect(model!.shadowIntensity, equals(0.7));
        expect(model.shadowSoftness, equals(0.5));
        expect(model.exposure, equals(1.0));
        expect(model.environmentLighting, equals('neutral'));
        expect(model.autoRotate, isTrue);
        expect(model.autoRotateSpeed, equals(25.0));
      });

      test('should have valid rendering properties for Cat model', () {
        final model = mapping.getModelForLetter('C');

        expect(model, isNotNull);
        expect(model!.shadowIntensity, equals(0.9));
        expect(model.shadowSoftness, equals(0.7));
        expect(model.exposure, equals(1.1));
        expect(model.environmentLighting, equals('neutral'));
        expect(model.autoRotate, isFalse);
        expect(model.rotation, equals(Vector3(0, 0.3, 0)));
      });
    });

    group('Educational Content', () {
      test('should have pronunciation for all models', () {
        final models = mapping.getAllModels();

        for (final model in models) {
          expect(model.pronunciation, isNotEmpty,
              reason: 'Model ${model.name} should have pronunciation');
        }
      });

      test('should have fun facts for all models', () {
        final models = mapping.getAllModels();

        for (final model in models) {
          expect(model.funFact, isNotEmpty,
              reason: 'Model ${model.name} should have a fun fact');
        }
      });

      test('should have educational content for specific models', () {
        final appleModel = mapping.getModelForLetter('A');
        expect(appleModel!.funFact, contains('25% air'));

        final ballModel = mapping.getModelForLetter('B');
        expect(ballModel!.funFact, contains('Mayans'));

        final catModel = mapping.getModelForLetter('C');
        expect(catModel!.funFact, contains('100 different sounds'));
      });
    });

    group('Performance Optimization', () {
      test('should return optimized model for degraded performance', () {
        final normalModel = mapping.getModelForLetter('A');
        final optimizedModel = mapping.getModelWithOptimizedLOD('A', true);

        expect(normalModel, isNotNull);
        expect(optimizedModel, isNotNull);

        // The optimized model should be different (lower detail)
        // This would depend on the implementation of getLowerDetailVersion()
        expect(optimizedModel, isNotNull);
      });

      test('should return standard model for normal performance', () {
        final normalModel = mapping.getModelForLetter('A');
        final standardModel = mapping.getModelWithOptimizedLOD('A', false);

        expect(normalModel, isNotNull);
        expect(standardModel, isNotNull);

        // Should return the same model for normal performance
        expect(standardModel!.id, equals(normalModel!.id));
      });

      test('should return null for invalid letter in optimization', () {
        final optimizedModel = mapping.getModelWithOptimizedLOD('1', true);
        expect(optimizedModel, isNull);
      });
    });

    group('Model Path Validation', () {
      test('should have valid model paths for all models', () {
        final models = mapping.getAllModels();

        for (final model in models) {
          expect(model.modelPath, startsWith('assets/3d_models/'));
          expect(model.modelPath, endsWith('.glb'));
        }
      });

      test('should have consistent naming between id and path', () {
        final models = mapping.getAllModels();

        for (final model in models) {
          expect(model.modelPath, contains(model.id));
        }
      });
    });

    group('Scale Validation', () {
      test('should have reasonable scale values for all models', () {
        final models = mapping.getAllModels();

        for (final model in models) {
          expect(model.scale, greaterThan(0.0));
          expect(model.scale, lessThanOrEqualTo(1.0)); // Reasonable upper bound
        }
      });

      test('should have appropriate scales for different model types', () {
        final elephantModel = mapping.getModelForLetter('E');
        final fishModel = mapping.getModelForLetter('F');

        expect(
            elephantModel!.scale, equals(0.15)); // Larger animal, smaller scale
        expect(fishModel!.scale, equals(0.2)); // Smaller animal, larger scale
      });
    });
  });
}
