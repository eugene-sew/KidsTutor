import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tts_settings.dart';

class TtsSettingsService {
  static const String _settingsKey = 'tts_settings';
  static TtsSettingsService? _instance;
  static TtsSettings? _cachedSettings;

  TtsSettingsService._();

  static TtsSettingsService get instance {
    _instance ??= TtsSettingsService._();
    return _instance!;
  }

  /// Load TTS settings from persistent storage
  Future<TtsSettings> loadSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        final Map<String, dynamic> settingsMap = json.decode(settingsJson);
        _cachedSettings = TtsSettings.fromJson(settingsMap);
      } else {
        _cachedSettings = const TtsSettings(); // Default settings
      }
    } catch (e) {
      _cachedSettings = const TtsSettings(); // Fallback to defaults
    }

    return _cachedSettings!;
  }

  /// Save TTS settings to persistent storage
  Future<void> saveSettings(TtsSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      _cachedSettings = settings;
    } catch (e) {
      // Handle save error silently for now
    }
  }

  /// Update specific setting and persist
  Future<void> updateSpeechRate(double rate) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(speechRate: rate));
  }

  Future<void> updateVolume(double volume) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(volume: volume));
  }

  Future<void> updatePitch(double pitch) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(pitch: pitch));
  }

  Future<void> updateLanguage(String language) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(language: language));
  }

  Future<void> updateVoice(String voice) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(voice: voice));
  }

  Future<void> updateEnabled(bool enabled) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(enabled: enabled));
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    await saveSettings(const TtsSettings());
  }
}
