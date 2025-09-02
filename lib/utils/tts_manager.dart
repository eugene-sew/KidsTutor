import 'package:flutter/foundation.dart';

enum TtsProvider { flutter, cloud }

enum TtsState { stopped, playing, paused, continued }

/// Abstract interface for TTS providers
abstract class TtsProviderInterface {
  Future<void> initialize();
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
  Future<void> setSpeechRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVolume(double volume);
  Future<List<Map<String, String>>> getVoices();
  Future<void> setVoice(Map<String, String> voice);
  TtsState get state;
}

/// TTS Manager that can switch between different providers
class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal();

  TtsProvider _currentProvider = TtsProvider.flutter;
  late TtsProviderInterface _currentTts;
  
  // Provider instances
  late FlutterTtsProvider _flutterTts;
  CloudTtsProvider? _cloudTts;

  bool _initialized = false;

  TtsProvider get currentProvider => _currentProvider;
  TtsState get state => _currentTts.state;

  Future<void> initialize({TtsProvider? provider}) async {
    if (_initialized && provider == null) return;

    _flutterTts = FlutterTtsProvider();
    // _cloudTts will be initialized when needed

    await switchProvider(provider ?? _currentProvider);
    _initialized = true;
  }

  Future<void> switchProvider(TtsProvider provider) async {
    _currentProvider = provider;
    
    switch (provider) {
      case TtsProvider.flutter:
        _currentTts = _flutterTts;
        break;
      case TtsProvider.cloud:
        _cloudTts ??= CloudTtsProvider();
        _currentTts = _cloudTts!;
        break;
    }

    await _currentTts.initialize();
  }

  Future<void> speak(String text) async {
    await _ensureInitialized();
    await _currentTts.speak(text);
  }

  Future<void> stop() async {
    await _ensureInitialized();
    await _currentTts.stop();
  }

  Future<void> pause() async {
    await _ensureInitialized();
    await _currentTts.pause();
  }

  Future<void> setSpeechRate(double rate) async {
    await _ensureInitialized();
    await _currentTts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _ensureInitialized();
    await _currentTts.setPitch(pitch);
  }

  Future<void> setVolume(double volume) async {
    await _ensureInitialized();
    await _currentTts.setVolume(volume);
  }

  Future<List<Map<String, String>>> getVoices() async {
    await _ensureInitialized();
    return await _currentTts.getVoices();
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _ensureInitialized();
    await _currentTts.setVoice(voice);
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}

/// Flutter TTS Provider Implementation
class FlutterTtsProvider implements TtsProviderInterface {
  late dynamic _flutterTts;
  TtsState _state = TtsState.stopped;
  bool _initialized = false;

  @override
  TtsState get state => _state;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // Dynamic import to avoid dependency issues
    try {
      final flutterTtsModule = await import('package:flutter_tts/flutter_tts.dart');
      _flutterTts = flutterTtsModule.FlutterTts();
    } catch (e) {
      if (kDebugMode) {
        print('[FlutterTTS] Error importing flutter_tts: $e');
      }
      return;
    }

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    _setupHandlers();
    _initialized = true;
  }

  void _setupHandlers() {
    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
    });

    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      if (kDebugMode) {
        print('[FlutterTTS] Error: $msg');
      }
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      _state = TtsState.continued;
    });
  }

  @override
  Future<void> speak(String text) async {
    if (!_initialized) await initialize();
    if (text.trim().isEmpty) return;

    if (_state == TtsState.playing) {
      await stop();
    }

    final result = await _flutterTts.speak(text);
    if (result == 1) {
      _state = TtsState.playing;
    }
  }

  @override
  Future<void> stop() async {
    if (!_initialized) return;
    final result = await _flutterTts.stop();
    if (result == 1) {
      _state = TtsState.stopped;
    }
  }

  @override
  Future<void> pause() async {
    if (!_initialized) return;
    await _flutterTts.pause();
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    if (!_initialized) return;
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    if (!_initialized) return;
    await _flutterTts.setPitch(pitch);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!_initialized) return;
    await _flutterTts.setVolume(volume);
  }

  @override
  Future<List<Map<String, String>>> getVoices() async {
    if (!_initialized) await initialize();
    try {
      final voices = await _flutterTts.getVoices;
      return voices.map<Map<String, String>>((v) => {
        'name': (v['name'] ?? '').toString(),
        'locale': (v['locale'] ?? '').toString(),
      }).where((v) => v['name']!.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) {
        print('[FlutterTTS] Error getting voices: $e');
      }
      return [];
    }
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    if (!_initialized) return;
    await _flutterTts.setVoice(voice);
  }
}

/// Cloud TTS Provider Implementation (placeholder for now)
class CloudTtsProvider implements TtsProviderInterface {
  TtsState _state = TtsState.stopped;
  bool _initialized = false;

  @override
  TtsState get state => _state;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    // TODO: Initialize cloud_text_to_speech when API keys are available
    if (kDebugMode) {
      print('[CloudTTS] Cloud TTS provider initialized (placeholder)');
    }
    _initialized = true;
  }

  @override
  Future<void> speak(String text) async {
    if (kDebugMode) {
      print('[CloudTTS] Would speak: $text');
    }
    // TODO: Implement cloud TTS speaking
  }

  @override
  Future<void> stop() async {
    _state = TtsState.stopped;
  }

  @override
  Future<void> pause() async {
    _state = TtsState.paused;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    if (kDebugMode) {
      print('[CloudTTS] Would set speech rate to: $rate');
    }
  }

  @override
  Future<void> setPitch(double pitch) async {
    if (kDebugMode) {
      print('[CloudTTS] Would set pitch to: $pitch');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (kDebugMode) {
      print('[CloudTTS] Would set volume to: $volume');
    }
  }

  @override
  Future<List<Map<String, String>>> getVoices() async {
    // TODO: Return cloud TTS voices
    return [
      {'name': 'Google Neural Voice', 'locale': 'en-US'},
      {'name': 'Amazon Polly Voice', 'locale': 'en-US'},
      {'name': 'Microsoft Azure Voice', 'locale': 'en-US'},
    ];
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    if (kDebugMode) {
      print('[CloudTTS] Would set voice to: ${voice['name']}');
    }
  }
}

// Helper function for dynamic imports
Future<dynamic> import(String package) async {
  // This is a placeholder - in real implementation, you'd use conditional imports
  throw UnsupportedError('Dynamic imports not supported in this context');
}
