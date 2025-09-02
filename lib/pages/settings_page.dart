import 'package:flutter/material.dart';
import '../widgets/settings/settings_section.dart';
import '../widgets/settings/settings_item.dart';
import '../widgets/settings/profile_settings.dart';
import '../ar/widgets/ar_settings_section.dart';
import '../ar/utils/settings_service.dart';
import '../utils/tts_service.dart';
import '../services/tts_settings_service.dart';
import '../models/tts_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Audio settings state
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _soundVolume = 0.7;
  double _musicVolume = 0.5;

  // Speech (TTS) state
  bool _autoSpeak = true;
  TtsSettings _ttsSettings = const TtsSettings();
  String _ttsVoiceName = '';
  String _pollyVoiceName = 'Joanna';
  List<Map<String, String>> _voices = [];
  List<Map<String, String>> _pollyVoices = [];

  // Profile settings initial values
  final String _initialName = "Alex";
  final int _initialAge = 5;
  final int _initialAvatarIndex = 0;

  // Parental controls initial values
  final int _initialTimeLimit = 30; // minutes
  final bool _initialPinProtection = false;

  @override
  void initState() {
    super.initState();
    _loadSpeechSettings();
  }

  Future<void> _loadSpeechSettings() async {
    final settings = SettingsService();
    if (!settings.isInitialized) await settings.initialize();
    
    // Load persisted TTS settings
    final ttsSettings = await TtsSettingsService.instance.loadSettings();
    
    // Initialize TTS service first
    await TtsService().initialize();
    await TtsService().loadProviderFromSettings();
    
    setState(() {
      _autoSpeak = settings.ttsAutoSpeak;
      _ttsSettings = ttsSettings;
      _ttsVoiceName = settings.ttsVoice;
      _pollyVoiceName = settings.ttsPollyVoice;
    });
    
    // Load voices with retry
    await _loadVoices();
    _loadPollyVoices();
  }

  Future<void> _loadVoices() async {
    try {
      print('Loading voices...');
      final voices = await TtsService().getVoices();
      print('Raw voices: $voices');
      
      final formattedVoices = voices.map((v) => {
        'name': (v['name'] ?? '').toString(),
        'locale': (v['locale'] ?? '').toString(),
      }).where((v) => v['name']!.isNotEmpty).toList();
      
      print('Formatted voices: $formattedVoices');
      setState(() => _voices = formattedVoices);
    } catch (e) {
      print('Error loading voices: $e');
    }
  }

  void _loadPollyVoices() {
    try {
      final pollyVoices = TtsService().getPollyVoices();
      setState(() => _pollyVoices = pollyVoices);
      print('Loaded ${_pollyVoices.length} Polly voices');
    } catch (e) {
      print('Error loading Polly voices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAudioSection(),
              _buildSpeechSection(),
              const ARSettingsSection(),
              _buildHelpAndSupportSection()
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeechSection() {
    return SettingsSection(
      title: 'Speech (TTS)',
      icon: Icons.record_voice_over,
      iconColor: Colors.purple,
      children: [
        ToggleSettingsItem(
          title: 'Auto-speak in AR',
          subtitle: 'Speak when recognition confidence ≥ 0.8',
          icon: Icons.volume_up,
          value: _autoSpeak,
          iconColor: Colors.purple,
          onChanged: (value) async {
            setState(() => _autoSpeak = value);
            await SettingsService().setTtsAutoSpeak(value);
          },
        ),
        const SizedBox(height: 8),
        SettingsItem(
          title: 'TTS Provider',
          subtitle: _getCurrentProviderName(),
          icon: Icons.settings_voice,
          iconColor: Colors.purple,
          trailing: DropdownButton<TtsProvider>(
            value: TtsService().currentProvider,
            items: TtsService().getAvailableProviders().map((provider) {
              return DropdownMenuItem<TtsProvider>(
                value: provider,
                child: Text(_getProviderDisplayName(provider)),
              );
            }).toList(),
            onChanged: (provider) async {
              if (provider != null) {
                await TtsService().switchProvider(provider);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${_getProviderDisplayName(provider)}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        SettingsItem(
          title: 'Voice Selection',
          subtitle: _getCurrentVoiceDisplayName(),
          icon: Icons.record_voice_over,
          iconColor: Colors.purple,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showVoiceSelectionDialog(),
        ),
        const SizedBox(height: 8),
        SliderSettingsItem(
          title: 'Speech Rate',
          subtitle: 'Adjust speaking speed',
          icon: Icons.speed,
          value: _ttsSettings.speechRate,
          min: 0.3,
          max: 1.0,
          iconColor: Colors.purple,
          onChanged: (value) async {
            final newSettings = _ttsSettings.copyWith(speechRate: value);
            setState(() => _ttsSettings = newSettings);
            await TtsService().setSpeechRate(value);
          },
        ),
        const SizedBox(height: 8),
        SliderSettingsItem(
          title: 'Pitch',
          subtitle: 'Adjust voice pitch',
          icon: Icons.tune,
          value: _ttsSettings.pitch,
          min: 0.8,
          max: 1.2,
          iconColor: Colors.purple,
          onChanged: (value) async {
            final newSettings = _ttsSettings.copyWith(pitch: value);
            setState(() => _ttsSettings = newSettings);
            await TtsService().setPitch(value);
          },
        ),
        const SizedBox(height: 8),
        SliderSettingsItem(
          title: 'Volume',
          subtitle: 'Adjust speech volume',
          icon: Icons.volume_up,
          value: _ttsSettings.volume,
          min: 0.3,
          max: 1.0,
          iconColor: Colors.purple,
          onChanged: (value) async {
            final newSettings = _ttsSettings.copyWith(volume: value);
            setState(() => _ttsSettings = newSettings);
            await TtsService().setVolume(value);
          },
        ),
        const SizedBox(height: 8),
        ToggleSettingsItem(
          title: 'TTS Enabled',
          subtitle: 'Enable or disable text-to-speech',
          icon: Icons.hearing,
          value: _ttsSettings.enabled,
          iconColor: Colors.purple,
          onChanged: (value) async {
            final newSettings = _ttsSettings.copyWith(enabled: value);
            setState(() => _ttsSettings = newSettings);
            await TtsSettingsService.instance.updateEnabled(value);
          },
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return SettingsSection(
      title: 'Profile Settings',
      icon: Icons.person,
      children: [
        ProfileSettings(
          initialName: _initialName,
          initialAge: _initialAge,
          initialAvatarIndex: _initialAvatarIndex,
          onSave: (name, age, avatarIndex) {
            // In a real app, we would save these values to persistent storage
            print(
              'Profile updated: name=$name, age=$age, avatarIndex=$avatarIndex',
            );
          },
        ),
      ],
    );
  }

  Widget _buildAudioSection() {
    return SettingsSection(
      title: 'Audio Settings',
      icon: Icons.volume_up,
      iconColor: Colors.orange,
      children: [
        ToggleSettingsItem(
          title: 'Sound Effects',
          subtitle: 'Enable sound effects in the app',
          icon: Icons.music_note,
          value: _soundEnabled,
          iconColor: Colors.orange,
          onChanged: (value) {
            setState(() {
              _soundEnabled = value;
            });
            print('Sound effects ${value ? 'enabled' : 'disabled'}');
          },
        ),
        const SizedBox(height: 8),
        SliderSettingsItem(
          title: 'Sound Volume',
          icon: Icons.volume_down,
          value: _soundVolume,
          iconColor: Colors.orange,
          onChanged: (value) {
            setState(() {
              _soundVolume = value;
            });
            print('Sound volume set to ${(value * 100).round()}%');
          },
        ),
        const SizedBox(height: 16),
        ToggleSettingsItem(
          title: 'Background Music',
          subtitle: 'Play music in the background',
          icon: Icons.library_music,
          value: _musicEnabled,
          iconColor: Colors.orange,
          onChanged: (value) {
            setState(() {
              _musicEnabled = value;
            });
            print('Background music ${value ? 'enabled' : 'disabled'}');
          },
        ),
        const SizedBox(height: 8),
        SliderSettingsItem(
          title: 'Music Volume',
          icon: Icons.music_video,
          value: _musicVolume,
          iconColor: Colors.orange,
          onChanged: (value) {
            setState(() {
              _musicVolume = value;
            });
            print('Music volume set to ${(value * 100).round()}%');
          },
        ),
      ],
    );
  }

  Widget _buildHelpAndSupportSection() {
    return SettingsSection(
      title: 'Help & Support',
      icon: Icons.help_outline,
      iconColor: Colors.blue,
      children: [
        SettingsItem(
          title: 'Frequently Asked Questions',
          subtitle: 'Find answers to common questions',
          icon: Icons.question_answer,
          iconColor: Colors.blue,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            print('Opening FAQs');
            _showComingSoonDialog('FAQs');
          },
        ),
        const SizedBox(height: 16),
        SettingsItem(
          title: 'Contact Support',
          subtitle: 'Get help from our support team',
          icon: Icons.support_agent,
          iconColor: Colors.blue,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            print('Opening Contact Support');
            _showComingSoonDialog('Contact Support');
          },
        ),
        const SizedBox(height: 16),
        SettingsItem(
          title: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          icon: Icons.privacy_tip,
          iconColor: Colors.blue,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            print('Opening Privacy Policy');
            _showComingSoonDialog('Privacy Policy');
          },
        ),
        const SizedBox(height: 16),
        SettingsItem(
          title: 'Terms of Service',
          subtitle: 'Read our terms of service',
          icon: Icons.description,
          iconColor: Colors.blue,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            print('Opening Terms of Service');
            _showComingSoonDialog('Terms of Service');
          },
        ),
        const SizedBox(height: 16),
        SettingsItem(
          title: 'About KidVerse',
          subtitle: 'Version 1.0.0',
          icon: Icons.info_outline,
          iconColor: Colors.blue,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            print('Opening About KidVerse');
            _showComingSoonDialog('About KidVerse');
          },
        ),
      ],
    );
  }

  void _showVoiceSelectionDialog() {
    final isCloudProvider = TtsService().currentProvider == TtsProvider.cloud;
    final voiceList = isCloudProvider ? _pollyVoices : _getFilteredVoices();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCloudProvider ? 'Select Polly Voice' : 'Select Voice'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Text(
                isCloudProvider 
                  ? 'Choose from premium Amazon Polly voices:'
                  : 'Choose a voice that sounds natural to you:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: voiceList.length,
                  itemBuilder: (context, index) {
                    final voice = voiceList[index];
                    final isSelected = isCloudProvider 
                      ? voice['id'] == _pollyVoiceName
                      : voice['name'] == _ttsVoiceName;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(isCloudProvider ? voice['name']! : voice['name']!),
                        subtitle: Text(isCloudProvider ? voice['gender']! : voice['locale']!),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => isCloudProvider 
                                ? _previewPollyVoice(voice)
                                : _previewVoice(voice),
                              tooltip: 'Preview voice',
                            ),
                            if (isSelected)
                              const Icon(Icons.check, color: Colors.green),
                          ],
                        ),
                        selected: isSelected,
                        onTap: () => isCloudProvider 
                          ? _selectPollyVoice(voice)
                          : _selectVoice(voice),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetToDefault();
            },
            child: const Text('Use Default'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await TtsSettingsService.instance.resetToDefaults();
              await _loadSpeechSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('TTS settings reset to defaults'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getFilteredVoices() {
    // Filter for more natural voices, prioritizing premium/enhanced voices
    return _voices.where((voice) {
      final name = voice['name']!.toLowerCase();
      final locale = voice['locale']!.toLowerCase();
      
      // Prioritize English voices
      if (!locale.startsWith('en')) return false;
      
      // Filter out obviously robotic voices
      if (name.contains('compact') || 
          name.contains('enhanced') && name.contains('compact')) {
        return false;
      }
      
      return true;
    }).toList();
  }

  Future<void> _previewVoice(Map<String, String> voice) async {
    try {
      // Temporarily set the voice
      await TtsService().setVoice(voice);
      // Speak a sample phrase
      await TtsService().speak('Hello! This is how I sound.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error previewing voice: $e')),
        );
      }
    }
  }

  Future<void> _selectVoice(Map<String, String> voice) async {
    try {
      await TtsService().setVoice(voice);
      await SettingsService().setTtsVoice(voice['name']!);
      setState(() => _ttsVoiceName = voice['name']!);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice changed to ${voice['name']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting voice: $e')),
        );
      }
    }
  }

  Future<void> _resetToDefault() async {
    try {
      final isCloudProvider = TtsService().currentProvider == TtsProvider.cloud;
      
      if (isCloudProvider) {
        await SettingsService().setTtsPollyVoice('Joanna');
        setState(() => _pollyVoiceName = 'Joanna');
      } else {
        await SettingsService().setTtsVoice('');
        setState(() => _ttsVoiceName = '');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCloudProvider 
              ? 'Voice reset to Joanna (default)'
              : 'Voice reset to system default'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting voice: $e')),
        );
      }
    }
  }

  String _getCurrentProviderName() {
    return _getProviderDisplayName(TtsService().currentProvider);
  }

  String _getProviderDisplayName(TtsProvider provider) {
    switch (provider) {
      case TtsProvider.flutter:
        return 'Flutter TTS (Built-in)';
      case TtsProvider.cloud:
        return 'Cloud TTS (Premium)';
    }
  }

  Future<void> _previewPollyVoice(Map<String, String> voice) async {
    try {
      // Temporarily switch to cloud provider and set voice
      final originalProvider = TtsService().currentProvider;
      if (originalProvider != TtsProvider.cloud) {
        await TtsService().switchProvider(TtsProvider.cloud);
      }
      
      // Save current voice and set preview voice
      final originalVoice = _pollyVoiceName;
      await SettingsService().setTtsPollyVoice(voice['id']!);
      
      // Speak sample text
      await TtsService().speak('Hello! I am ${voice['name']}. This is how I sound.');
      
      // Restore original voice
      await SettingsService().setTtsPollyVoice(originalVoice);
      
      // Restore original provider if needed
      if (originalProvider != TtsProvider.cloud) {
        await TtsService().switchProvider(originalProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error previewing Polly voice: $e')),
        );
      }
    }
  }

  Future<void> _selectPollyVoice(Map<String, String> voice) async {
    try {
      await SettingsService().setTtsPollyVoice(voice['id']!);
      setState(() => _pollyVoiceName = voice['id']!);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice changed to ${voice['name']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting Polly voice: $e')),
        );
      }
    }
  }

  String _getCurrentVoiceDisplayName() {
    final isCloudProvider = TtsService().currentProvider == TtsProvider.cloud;
    
    if (isCloudProvider) {
      final pollyVoice = _pollyVoices.firstWhere(
        (v) => v['id'] == _pollyVoiceName,
        orElse: () => {'name': _pollyVoiceName, 'id': _pollyVoiceName},
      );
      return pollyVoice['name'] ?? _pollyVoiceName;
    } else {
      return _ttsVoiceName.isEmpty ? 'System default' : _ttsVoiceName;
    }
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$feature Coming Soon'),
        content: Text('The $feature feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
