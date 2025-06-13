import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ParentalControls extends StatefulWidget {
  final int initialTimeLimit;
  final bool initialPinProtection;
  final Function(int, bool) onSave;

  const ParentalControls({
    super.key,
    required this.initialTimeLimit,
    required this.initialPinProtection,
    required this.onSave,
  });

  @override
  State<ParentalControls> createState() => _ParentalControlsState();
}

class _ParentalControlsState extends State<ParentalControls> {
  late int _timeLimit;
  late bool _pinProtection;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    _timeLimit = widget.initialTimeLimit;
    _pinProtection = widget.initialPinProtection;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeLimitSelector(),
        const SizedBox(height: 24),
        _buildPinProtection(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _validateAndSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save Parental Controls'),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeLimitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Time Limit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _timeLimit.toDouble(),
                min: 15,
                max: 120,
                divisions: 7,
                label: '${_timeLimit.toString()} min',
                onChanged: (double value) {
                  setState(() {
                    _timeLimit = value.round();
                  });
                },
              ),
            ),
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_timeLimit min',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Text(
          'Set how long your child can use the app each day',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPinProtection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'PIN Protection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Switch(
              value: _pinProtection,
              onChanged: (value) {
                setState(() {
                  _pinProtection = value;
                });
              },
            ),
          ],
        ),
        Text(
          'Require a PIN to access parental controls',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        if (_pinProtection) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            decoration: InputDecoration(
              labelText: 'Enter PIN (4 digits)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showPin ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  setState(() {
                    _showPin = !_showPin;
                  });
                },
              ),
            ),
            keyboardType: TextInputType.number,
            obscureText: !_showPin,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPinController,
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showPin ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  setState(() {
                    _showPin = !_showPin;
                  });
                },
              ),
            ),
            keyboardType: TextInputType.number,
            obscureText: !_showPin,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
        ],
      ],
    );
  }

  void _validateAndSave() {
    if (_pinProtection) {
      if (_pinController.text.length != 4) {
        _showErrorSnackBar('PIN must be 4 digits');
        return;
      }
      
      if (_pinController.text != _confirmPinController.text) {
        _showErrorSnackBar('PINs do not match');
        return;
      }
    }
    
    widget.onSave(_timeLimit, _pinProtection);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Parental controls updated successfully!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    print('Parental controls saved: Time limit: $_timeLimit minutes, PIN protection: $_pinProtection');
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
