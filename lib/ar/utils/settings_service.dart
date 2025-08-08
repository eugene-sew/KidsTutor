import 'package:shared_preferences/shared_preferences.dart';

/// A singleton service for managing app settings and preferences
class SettingsService {
  // Singleton instance
  static final SettingsService _instance = SettingsService._internal();

  // Factory constructor to return the singleton instance
  factory SettingsService() => _instance;

  // Private constructor
  SettingsService._internal();

  // Shared preferences instance
  SharedPreferences? _prefs;

  // Constants for preference keys
  static const String _keyAREnabled = 'ar_enabled';
  static const String _keyARQuality = 'ar_quality';
  static const String _keyShowDebugInfo = 'show_debug_info';

  /// Initialize the settings service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if the service is initialized
  bool get isInitialized => _prefs != null;

  /// Get whether AR features are enabled
  bool get isAREnabled {
    _ensureInitialized();
    return _prefs!.getBool(_keyAREnabled) ?? true;
  }

  /// Set whether AR features are enabled
  Future<void> setAREnabled(bool value) async {
    _ensureInitialized();
    await _prefs!.setBool(_keyAREnabled, value);
  }

  /// Get the AR quality setting (0 = low, 1 = medium, 2 = high)
  int get arQuality {
    _ensureInitialized();
    return _prefs!.getInt(_keyARQuality) ?? 1; // Default to medium
  }

  /// Set the AR quality setting
  Future<void> setARQuality(int value) async {
    _ensureInitialized();
    await _prefs!.setInt(_keyARQuality, value.clamp(0, 2));
  }

  /// Get whether to show debug information
  bool get showDebugInfo {
    _ensureInitialized();
    return _prefs!.getBool(_keyShowDebugInfo) ?? false;
  }

  /// Set whether to show debug information
  Future<void> setShowDebugInfo(bool value) async {
    _ensureInitialized();
    await _prefs!.setBool(_keyShowDebugInfo, value);
  }

  /// Ensure the service is initialized
  void _ensureInitialized() {
    if (_prefs == null) {
      throw StateError(
          'SettingsService not initialized. Call initialize() first.');
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _ensureInitialized();
    await _prefs!.setBool(_keyAREnabled, true);
    await _prefs!.setInt(_keyARQuality, 1);
    await _prefs!.setBool(_keyShowDebugInfo, false);
  }
}
