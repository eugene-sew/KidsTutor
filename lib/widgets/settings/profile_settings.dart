import 'package:flutter/material.dart';

class ProfileSettings extends StatefulWidget {
  final String initialName;
  final int initialAge;
  final int initialAvatarIndex;
  final Function(String, int, int) onSave;

  const ProfileSettings({
    super.key,
    required this.initialName,
    required this.initialAge,
    required this.initialAvatarIndex,
    required this.onSave,
  });

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  late TextEditingController _nameController;
  late int _age;
  late int _selectedAvatarIndex;
  final List<Color> _avatarColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _age = widget.initialAge;
    _selectedAvatarIndex = widget.initialAvatarIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              _buildAvatarSelector(),
              const SizedBox(height: 16),
              Text(
                'Choose your avatar',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Child\'s Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Age:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAgeSelector(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.onSave(_nameController.text, _age, _selectedAvatarIndex);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              print('Profile saved: ${_nameController.text}, $_age years old, avatar: $_selectedAvatarIndex');
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save Profile'),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSelector() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _avatarColors.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedAvatarIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedAvatarIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                    : null,
              ),
              child: CircleAvatar(
                radius: isSelected ? 36 : 32,
                backgroundColor: _avatarColors[index],
                child: Icon(
                  Icons.person,
                  size: isSelected ? 36 : 32,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAgeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: _age > 2
                ? () {
                    setState(() {
                      _age--;
                    });
                  }
                : null,
          ),
          Text(
            '$_age years',
            style: const TextStyle(fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _age < 12
                ? () {
                    setState(() {
                      _age++;
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
