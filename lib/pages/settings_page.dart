import 'package:flutter/material.dart';
import '../widgets/settings/settings_section.dart';
import '../widgets/settings/settings_item.dart';
import '../widgets/settings/profile_settings.dart';
import '../widgets/settings/parental_controls.dart';

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

  // Profile settings initial values
  final String _initialName = "Alex";
  final int _initialAge = 5;
  final int _initialAvatarIndex = 0;

  // Parental controls initial values
  final int _initialTimeLimit = 30; // minutes
  final bool _initialPinProtection = false;

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
              _buildProfileSection(),
              _buildAudioSection(),
              _buildParentalControlsSection(),
              _buildHelpAndSupportSection(),
            ],
          ),
        ),
      ),
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

  Widget _buildParentalControlsSection() {
    return SettingsSection(
      title: 'Parental Controls',
      icon: Icons.security,
      iconColor: Colors.green,
      children: [
        ParentalControls(
          initialTimeLimit: _initialTimeLimit,
          initialPinProtection: _initialPinProtection,
          onSave: (timeLimit, pinProtection) {
            // In a real app, we would save these values to persistent storage
            print(
              'Parental controls updated: timeLimit=$timeLimit, pinProtection=$pinProtection',
            );
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

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
