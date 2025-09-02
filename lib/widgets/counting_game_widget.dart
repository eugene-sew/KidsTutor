import 'package:flutter/material.dart';
import 'dart:math';
import '../utils/tts_service.dart';

class CountingGameWidget extends StatefulWidget {
  const CountingGameWidget({super.key});

  @override
  State<CountingGameWidget> createState() => _CountingGameWidgetState();
}

class _CountingGameWidgetState extends State<CountingGameWidget> {
  int _targetNumber = 1;
  int _selectedCount = 0;
  bool _isCorrect = false;
  bool _gameCompleted = false;
  List<bool> _selectedItems = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _generateNewQuestion();
  }

  void _generateNewQuestion() {
    setState(() {
      _targetNumber = _random.nextInt(10) + 1; // Numbers 1-10
      _selectedCount = 0;
      _isCorrect = false;
      _gameCompleted = false;
      _selectedItems = List.generate(15, (index) => false); // Max 15 items to choose from
    });
    
    _speakQuestion();
  }

  Future<void> _speakQuestion() async {
    await TtsService().speak('Count and select $_targetNumber items. Tap on the circles to count them.');
  }

  void _onItemTapped(int index) {
    if (_gameCompleted) return;

    setState(() {
      if (_selectedItems[index]) {
        _selectedItems[index] = false;
        _selectedCount--;
      } else if (_selectedCount < _targetNumber) {
        _selectedItems[index] = true;
        _selectedCount++;
      }

      _isCorrect = _selectedCount == _targetNumber;
      
      if (_isCorrect) {
        _gameCompleted = true;
        _speakSuccess();
      }
    });
  }

  Future<void> _speakSuccess() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await TtsService().speak('Excellent! You counted $_targetNumber correctly! Well done!');
  }

  Future<void> _speakCount() async {
    if (_selectedCount == 0) {
      await TtsService().speak('You haven\'t selected any items yet. Tap the circles to count.');
    } else if (_selectedCount == 1) {
      await TtsService().speak('You have selected one item.');
    } else {
      await TtsService().speak('You have selected $_selectedCount items.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game header
          Row(
            children: [
              Icon(Icons.games, color: Colors.blue.shade600, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Counting Game',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Count and select $_targetNumber items',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selected: $_selectedCount / $_targetNumber',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isCorrect ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Counting items grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: 15,
            itemBuilder: (context, index) {
              final isSelected = _selectedItems[index];
              return GestureDetector(
                onTap: () => _onItemTapped(index),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.green.shade400 : Colors.grey.shade300,
                    border: Border.all(
                      color: isSelected ? Colors.green.shade600 : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _speakCount,
                icon: const Icon(Icons.volume_up),
                label: const Text('Count'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedItems = List.generate(15, (index) => false);
                    _selectedCount = 0;
                    _isCorrect = false;
                    _gameCompleted = false;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _gameCompleted ? _generateNewQuestion : null,
                icon: const Icon(Icons.skip_next),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          
          // Success message
          if (_gameCompleted)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perfect! You counted $_targetNumber correctly! 🎉',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
