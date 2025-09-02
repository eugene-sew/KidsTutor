import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/tts_config.dart';
import '../ar/utils/settings_service.dart';
import '../services/tts_settings_service.dart';
import 'polly_tts_service.dart';

enum TtsState { stopped, playing, paused, continued }
enum TtsProvider { flutter, cloud }

/// Enhanced Text-to-Speech service with provider switching
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  TtsState _ttsState = TtsState.stopped;
  TtsProvider _currentProvider = TtsProvider.flutter;
  bool _initialized = false;

  TtsState get ttsState => _ttsState;
  TtsProvider get currentProvider => _currentProvider;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load persisted TTS settings
      final settings = await TtsSettingsService.instance.loadSettings();
      
      // Set up TTS configuration from persisted settings
      await _flutterTts.setLanguage(settings.language);
      await _flutterTts.setSpeechRate(settings.speechRate);
      await _flutterTts.setVolume(settings.volume);
      await _flutterTts.setPitch(settings.pitch);
      await _flutterTts.awaitSpeakCompletion(true);

    // Set up handlers
    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      if (kDebugMode) {
        print('[TTS] Started speaking');
      }
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      if (kDebugMode) {
        print('[TTS] Completed speaking');
      }
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
      if (kDebugMode) {
        print('[TTS] Error: $msg');
      }
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
      if (kDebugMode) {
        print('[TTS] Cancelled');
      }
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
      if (kDebugMode) {
        print('[TTS] Paused');
      }
    });

    _flutterTts.setContinueHandler(() {
      _ttsState = TtsState.continued;
      if (kDebugMode) {
        print('[TTS] Continued');
      }
    });

      _initialized = true;
      if (kDebugMode) {
        print('[TTS] Service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[TTS] Initialization error: $e');
      }
      _initialized = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    
    await _ensureInitialized();
    
    // Stop any current speech before starting new one
    if (_ttsState == TtsState.playing) {
      await stop();
    }
    
    if (_currentProvider == TtsProvider.cloud && TtsConfig.isAmazonConfigured) {
      await _speakWithPolly(text);
    } else {
      final result = await _flutterTts.speak(text);
      if (result == 1) {
        _ttsState = TtsState.playing;
      }
    }
  }

  Future<void> stop() async {
    await _ensureInitialized();
    
    // Stop both TTS providers
    await _audioPlayer.stop();
    final result = await _flutterTts.stop();
    if (result == 1) {
      _ttsState = TtsState.stopped;
    }
  }

  Future<void> pause() async {
    await _ensureInitialized();
    
    if (_currentProvider == TtsProvider.cloud) {
      await _audioPlayer.pause();
    } else {
      await _flutterTts.pause();
    }
  }

  Future<List<dynamic>> getLanguages() async {
    await _ensureInitialized();
    return await _flutterTts.getLanguages;
  }

  Future<void> setLanguage(String language) async {
    await _ensureInitialized();
    await _flutterTts.setLanguage(language);
    await TtsSettingsService.instance.updateLanguage(language);
  }

  Future<void> setSpeechRate(double rate) async {
    await _ensureInitialized();
    await _flutterTts.setSpeechRate(rate);
    await TtsSettingsService.instance.updateSpeechRate(rate);
    if (kDebugMode) {
      print('[TTS] Speech rate set to: $rate');
    }
  }

  Future<void> setVolume(double volume) async {
    await _ensureInitialized();
    await _flutterTts.setVolume(volume);
    await TtsSettingsService.instance.updateVolume(volume);
    if (kDebugMode) {
      print('[TTS] Volume set to: $volume');
    }
  }

  Future<void> setPitch(double pitch) async {
    await _ensureInitialized();
    await _flutterTts.setPitch(pitch);
    await TtsSettingsService.instance.updatePitch(pitch);
    if (kDebugMode) {
      print('[TTS] Pitch set to: $pitch');
    }
  }

  Future<List<Map>> getVoices() async {
    await _ensureInitialized();
    try {
      final voices = await _flutterTts.getVoices;
      if (kDebugMode) {
        print('[TTS] Found ${voices.length} voices');
      }
      return voices;
    } catch (e) {
      if (kDebugMode) {
        print('[TTS] Error getting voices: $e');
      }
      return [];
    }
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _ensureInitialized();
    try {
      await _flutterTts.setVoice(voice);
      if (kDebugMode) {
        print('[TTS] Voice set to: ${voice['name']} (${voice['locale']})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[TTS] Error setting voice: $e');
      }
    }
  }

  Future<void> switchProvider(TtsProvider provider) async {
    _currentProvider = provider;
    if (kDebugMode) {
      print('[TTS] Switched to provider: $provider');
    }
    
    if (provider == TtsProvider.cloud && !TtsConfig.isAmazonConfigured) {
      if (kDebugMode) {
        print('[TTS] Warning: Cloud provider selected but no API keys configured');
      }
      _currentProvider = TtsProvider.flutter; // Fallback
    }
    
    // Save provider preference
    final settings = SettingsService();
    if (settings.isInitialized) {
      await settings.setTtsProvider(provider == TtsProvider.cloud ? 'cloud' : 'flutter');
    }
  }

  List<TtsProvider> getAvailableProviders() {
    final providers = [TtsProvider.flutter];
    if (TtsConfig.isAnyCloudProviderConfigured) {
      providers.add(TtsProvider.cloud);
    }
    return providers;
  }

  Future<bool> isLanguageAvailable(String language) async {
    await _ensureInitialized();
    return await _flutterTts.isLanguageAvailable(language);
  }

  /// Speak using Amazon Polly
  Future<void> _speakWithPolly(String text) async {
    try {
      _ttsState = TtsState.playing;
      
      // Get selected Polly voice from settings
      final settings = SettingsService();
      final selectedVoice = settings.isInitialized ? settings.ttsPollyVoice : 'Joanna';
      
      // Get audio data from Polly
      final audioData = await PollyTtsService.synthesizeSpeech(
        text: text,
        voiceId: selectedVoice,
        outputFormat: 'mp3',
        engine: 'neural',
      );
      
      if (audioData != null) {
        // Save to temporary file and play
        await _playAudioData(audioData);
      } else {
        if (kDebugMode) {
          print('[TTS] Polly synthesis failed, falling back to Flutter TTS');
        }
        // Fallback to Flutter TTS
        final result = await _flutterTts.speak(text);
        if (result == 1) {
          _ttsState = TtsState.playing;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[TTS] Polly error: $e, falling back to Flutter TTS');
      }
      // Fallback to Flutter TTS
      final result = await _flutterTts.speak(text);
      if (result == 1) {
        _ttsState = TtsState.playing;
      }
    }
  }

  /// Play audio data from bytes
  Future<void> _playAudioData(Uint8List audioData) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/polly_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
      
      // Write audio data to file
      await tempFile.writeAsBytes(audioData);
      
      if (kDebugMode) {
        print('[TTS] Polly audio saved to: ${tempFile.path}');
        print('[TTS] Audio file size: ${audioData.length} bytes');
      }
      
      // Set up audio player event listeners
      _audioPlayer.onPlayerComplete.listen((event) {
        _ttsState = TtsState.stopped;
        if (kDebugMode) {
          print('[TTS] Polly audio playback completed');
        }
        // Clean up the temp file
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      });
      
      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
        switch (state) {
          case PlayerState.playing:
            _ttsState = TtsState.playing;
            break;
          case PlayerState.paused:
            _ttsState = TtsState.paused;
            break;
          case PlayerState.stopped:
          case PlayerState.completed:
            _ttsState = TtsState.stopped;
            break;
          case PlayerState.disposed:
            _ttsState = TtsState.stopped;
            break;
        }
      });
      
      // Play the audio file
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      
    } catch (e) {
      if (kDebugMode) {
        print('[TTS] Error playing Polly audio: $e');
      }
      _ttsState = TtsState.stopped;
    }
  }

  /// Get available Polly voices for children
  List<Map<String, String>> getPollyVoices() {
    return PollyTtsService.getChildFriendlyVoices();
  }

  /// Initialize provider from settings
  Future<void> loadProviderFromSettings() async {
    final settings = SettingsService();
    if (settings.isInitialized) {
      final providerName = settings.ttsProvider;
      if (providerName == 'cloud' && TtsConfig.isAmazonConfigured) {
        _currentProvider = TtsProvider.cloud;
      } else {
        _currentProvider = TtsProvider.flutter;
      }
    }
  }
}
