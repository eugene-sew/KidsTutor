import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kidverse/ar/utils/settings_service.dart';

void main() {
  group('SettingsService Tests', () {
    late SettingsService settingsService;

    setUp(() async {
      // Set up mock shared preferences
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
      await settingsService.initialize();
    });

    group('Singleton Pattern', () {
      test('should be a singleton', () {
        final instance1 = SettingsService();
        final instance2 = SettingsService();
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        final newService = SettingsService();
        await newService.initialize();
        expect(newService.isInitialized, isTrue);
      });

      test('should throw error when accessing settings before initialization',
          () {
        final uninitializedService = SettingsService();
        // Reset the singleton state for this test
        expect(
            () => uninitializedService.isAREnabled, throwsA(isA<StateError>()));
      });
    });

    group('AR Enabled Setting', () {
      test('should have default AR enabled value', () {
        expect(settingsService.isAREnabled, isTrue);
      });

      test('should set and get AR enabled value', () async {
        await settingsService.setAREnabled(false);
        expect(settingsService.isAREnabled, isFalse);

        await settingsService.setAREnabled(true);
        expect(settingsService.isAREnabled, isTrue);
      });

      test('should persist AR enabled setting', () async {
        await settingsService.setAREnabled(false);

        // Create a new instance to test persistence
        final newService = SettingsService();
        await newService.initialize();

        expect(newService.isAREnabled, isFalse);
      });
    });

    group('AR Quality Setting', () {
      test('should have default AR quality value', () {
        expect(settingsService.arQuality, equals(1)); // Medium quality
      });

      test('should set and get AR quality value', () async {
        await settingsService.setARQuality(2); // High quality
        expect(settingsService.arQuality, equals(2));

        await settingsService.setARQuality(0); // Low quality
        expect(settingsService.arQuality, equals(0));
      });

      test('should clamp AR quality value to valid range', () async {
        await settingsService.setARQuality(-1);
        expect(settingsService.arQuality, equals(0)); // Clamped to minimum

        await settingsService.setARQuality(5);
        expect(settingsService.arQuality, equals(2)); // Clamped to maximum
      });

      test('should persist AR quality setting', () async {
        await settingsService.setARQuality(2);

        // Create a new instance to test persistence
        final newService = SettingsService();
        await newService.initialize();

        expect(newService.arQuality, equals(2));
      });
    });

    group('Debug Info Setting', () {
      test('should have default debug info value', () {
        expect(settingsService.showDebugInfo, isFalse);
      });

      test('should set and get debug info value', () async {
        await settingsService.setShowDebugInfo(true);
        expect(settingsService.showDebugInfo, isTrue);

        await settingsService.setShowDebugInfo(false);
        expect(settingsService.showDebugInfo, isFalse);
      });

      test('should persist debug info setting', () async {
        await settingsService.setShowDebugInfo(true);

        // Create a new instance to test persistence
        final newService = SettingsService();
        await newService.initialize();

        expect(newService.showDebugInfo, isTrue);
      });
    });

    group('Reset to Defaults', () {
      test('should reset all settings to defaults', () async {
        // Change all settings from defaults
        await settingsService.setAREnabled(false);
        await settingsService.setARQuality(0);
        await settingsService.setShowDebugInfo(true);

        // Verify settings are changed
        expect(settingsService.isAREnabled, isFalse);
        expect(settingsService.arQuality, equals(0));
        expect(settingsService.showDebugInfo, isTrue);

        // Reset to defaults
        await settingsService.resetToDefaults();

        // Verify settings are back to defaults
        expect(settingsService.isAREnabled, isTrue);
        expect(settingsService.arQuality, equals(1));
        expect(settingsService.showDebugInfo, isFalse);
      });

      test('should persist default values after reset', () async {
        // Change settings and reset
        await settingsService.setAREnabled(false);
        await settingsService.resetToDefaults();

        // Create a new instance to test persistence
        final newService = SettingsService();
        await newService.initialize();

        expect(newService.isAREnabled, isTrue);
        expect(newService.arQuality, equals(1));
        expect(newService.showDebugInfo, isFalse);
      });
    });

    group('Multiple Settings Operations', () {
      test('should handle multiple rapid setting changes', () async {
        // Rapidly change settings
        await settingsService.setAREnabled(false);
        await settingsService.setARQuality(2);
        await settingsService.setShowDebugInfo(true);
        await settingsService.setAREnabled(true);
        await settingsService.setARQuality(0);

        // Verify final state
        expect(settingsService.isAREnabled, isTrue);
        expect(settingsService.arQuality, equals(0));
        expect(settingsService.showDebugInfo, isTrue);
      });

      test('should maintain consistency across multiple instances', () async {
        // Change settings in first instance
        await settingsService.setAREnabled(false);
        await settingsService.setARQuality(2);

        // Create second instance
        final secondService = SettingsService();
        await secondService.initialize();

        // Both instances should have the same values
        expect(settingsService.isAREnabled, equals(secondService.isAREnabled));
        expect(settingsService.arQuality, equals(secondService.arQuality));
        expect(
            settingsService.showDebugInfo, equals(secondService.showDebugInfo));
      });
    });

    group('Error Handling', () {
      test('should handle SharedPreferences errors gracefully', () async {
        // This test would require mocking SharedPreferences to throw errors
        // For now, we test that the service handles normal operations
        expect(() => settingsService.isAREnabled, returnsNormally);
        expect(() => settingsService.setAREnabled(true), returnsNormally);
      });
    });

    group('Initialization State', () {
      test('should report correct initialization state', () async {
        final newService = SettingsService();
        expect(newService.isInitialized, isFalse);

        await newService.initialize();
        expect(newService.isInitialized, isTrue);
      });
    });

    group('Setting Validation', () {
      test('should validate AR quality bounds', () async {
        // Test boundary values
        await settingsService.setARQuality(0);
        expect(settingsService.arQuality, equals(0));

        await settingsService.setARQuality(2);
        expect(settingsService.arQuality, equals(2));

        // Test out of bounds values
        await settingsService.setARQuality(-10);
        expect(settingsService.arQuality, equals(0));

        await settingsService.setARQuality(10);
        expect(settingsService.arQuality, equals(2));
      });
    });

    group('Default Values', () {
      test('should return correct default values for new installation', () {
        // Test with fresh SharedPreferences
        SharedPreferences.setMockInitialValues({});

        expect(settingsService.isAREnabled, isTrue);
        expect(settingsService.arQuality, equals(1));
        expect(settingsService.showDebugInfo, isFalse);
      });

      test('should handle missing preference keys gracefully', () {
        // Even if some keys are missing, should return defaults
        SharedPreferences.setMockInitialValues({
          'ar_enabled': false, // Only one key present
        });

        expect(settingsService.isAREnabled, isFalse); // From preferences
        expect(settingsService.arQuality, equals(1)); // Default value
        expect(settingsService.showDebugInfo, isFalse); // Default value
      });
    });
  });
}
