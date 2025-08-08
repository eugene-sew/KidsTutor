import 'package:flutter/material.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/settings/settings_item.dart';
import '../utils/settings_service.dart';

class ARSettingsSection extends StatefulWidget {
  const ARSettingsSection({Key? key}) : super(key: key);

  @override
  State<ARSettingsSection> createState() => _ARSettingsState();
}

class _ARSettingsState extends State<ARSettingsSection> {
  final SettingsService _settings = SettingsService();
  bool _isAREnabled = true;
  int _arQuality = 1;
  bool _showDebugInfo = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!_settings.isInitialized) {
      await _settings.initialize();
    }

    setState(() {
      _isAREnabled = _settings.isAREnabled;
      _arQuality = _settings.arQuality;
      _showDebugInfo = _settings.showDebugInfo;
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return SettingsSection(
      title: 'Augmented Reality',
      icon: Icons.view_in_ar,
      iconColor: Colors.purple,
      children: [
        ToggleSettingsItem(
          title: 'Enable AR Features',
          subtitle: 'Show 3D models in augmented reality',
          icon: Icons.view_in_ar_outlined,
          value: _isAREnabled,
          iconColor: Colors.purple,
          onChanged: (value) async {
            setState(() {
              _isAREnabled = value;
            });
            await _settings.setAREnabled(value);
            debugPrint('AR features ${value ? 'enabled' : 'disabled'}');
          },
        ),
        const SizedBox(height: 16),
        SettingsItem(
          title: 'AR Quality',
          subtitle: _getQualityText(),
          icon: Icons.high_quality,
          iconColor: Colors.purple,
          trailing: DropdownButton<int>(
            value: _arQuality,
            onChanged: (int? value) async {
              if (value != null) {
                setState(() {
                  _arQuality = value;
                });
                await _settings.setARQuality(value);
                debugPrint('AR quality set to ${_getQualityText()}');
              }
            },
            items: const [
              DropdownMenuItem(
                value: 0,
                child: Text('Low'),
              ),
              DropdownMenuItem(
                value: 1,
                child: Text('Medium'),
              ),
              DropdownMenuItem(
                value: 2,
                child: Text('High'),
              ),
            ],
            underline: Container(),
          ),
        ),
        const SizedBox(height: 16),
        ToggleSettingsItem(
          title: 'Show Debug Info',
          subtitle: 'Display technical information for debugging',
          icon: Icons.bug_report,
          value: _showDebugInfo,
          iconColor: Colors.purple,
          onChanged: (value) async {
            setState(() {
              _showDebugInfo = value;
            });
            await _settings.setShowDebugInfo(value);
            debugPrint('Debug info ${value ? 'enabled' : 'disabled'}');
          },
        ),
        const SizedBox(height: 16),
        SettingsItem(
          title: 'Reset AR Settings',
          subtitle: 'Restore default AR settings',
          icon: Icons.restore,
          iconColor: Colors.purple,
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Reset AR Settings'),
                content: const Text(
                  'Are you sure you want to reset all AR settings to their default values?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('RESET'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await _settings.resetToDefaults();
              await _loadSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AR settings have been reset to defaults'),
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }

  String _getQualityText() {
    switch (_arQuality) {
      case 0:
        return 'Low (better performance)';
      case 1:
        return 'Medium (balanced)';
      case 2:
        return 'High (better visuals)';
      default:
        return 'Medium (balanced)';
    }
  }
}
