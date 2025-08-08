import 'package:flutter/material.dart';

/// A widget that toggles between AR mode and normal mode
class ARModeToggle extends StatelessWidget {
  /// Whether AR mode is currently active
  final bool isARModeActive;

  /// Callback when the toggle is pressed
  final VoidCallback onToggle;

  /// Constructor
  const ARModeToggle({
    Key? key,
    required this.isARModeActive,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isARModeActive
              ? Theme.of(context).colorScheme.primary
              : Colors.grey
                  .withValues(red: 100, green: 100, blue: 100, alpha: 180),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 50),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isARModeActive ? Icons.view_in_ar : Icons.camera_alt,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isARModeActive ? 'AR Mode' : 'Camera Mode',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
