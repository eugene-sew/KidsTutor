import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  TTSService._internal();
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  String _language = 'en-US';
  double _rate = 0.6;
  double _pitch = 1.05;
  double _volume = 1.0;

  Future<void> init({String language = 'en-US', double rate = 0.6, double pitch = 1.05, double volume = 1.0}) async {
    if (_initialized) return;
    _language = language;
    _rate = rate;
    _pitch = pitch;
    _volume = volume;
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(_volume);
    // Prefer offline if available
    await _tts.awaitSpeakCompletion(true);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_initialized) {
      await init();
    }
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  // Runtime setters
  Future<void> setLanguage(String language) async {
    _language = language;
    try { await _tts.setLanguage(language); } catch (_) {}
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    try { await _tts.setSpeechRate(rate); } catch (_) {}
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    try { await _tts.setPitch(pitch); } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    try { await _tts.setVolume(volume); } catch (_) {}
  }

  // Getters (optional use)
  String get language => _language;
  double get rate => _rate;
  double get pitch => _pitch;
  double get volume => _volume;
}
