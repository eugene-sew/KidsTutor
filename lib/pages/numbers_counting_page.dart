import 'package:flutter/material.dart';
import '../modules/education_content.dart';
import '../utils/tts_service.dart';
import '../widgets/counting_game_widget.dart';

class NumbersCountingPage extends StatefulWidget {
  const NumbersCountingPage({super.key});

  @override
  State<NumbersCountingPage> createState() => _NumbersCountingPageState();
}

class _NumbersCountingPageState extends State<NumbersCountingPage> {
  List<AlphabetContent> _numberContents = [];
  int _currentIndex = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadNumberContents();
  }

  void _loadNumberContents() {
    final contents = getContentsByModelName('Numbers & Counting');
    setState(() {
      _numberContents = contents;
    });
  }

  Future<void> _speakNumber(AlphabetContent content) async {
    if (_isPlaying) return;
    
    setState(() => _isPlaying = true);
    
    try {
      // First speak the number
      await TtsService().speak('${content.word}');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Then speak the pronunciation guide
      await TtsService().speak('Let me say it slowly: ${content.pronunciation}');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Finally speak the fun fact
      await TtsService().speak(content.funFact);
    } catch (e) {
      print('Error speaking number: $e');
    } finally {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _practiceCountingSequence() async {
    if (_isPlaying) return;
    
    setState(() => _isPlaying = true);
    
    try {
      await TtsService().speak('Let\'s count together from 1 to 10!');
      await Future.delayed(const Duration(milliseconds: 1000));
      
      for (int i = 0; i < 10 && i < _numberContents.length; i++) {
        final content = _numberContents[i];
        if (content.letter.isNotEmpty && int.tryParse(content.letter) != null) {
          await TtsService().speak(content.word);
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
      
      await TtsService().speak('Great job counting! You\'re getting better at numbers!');
    } catch (e) {
      print('Error in counting sequence: $e');
    } finally {
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Numbers & Counting'),
        backgroundColor: Colors.blue.shade100,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
            onPressed: _isPlaying ? null : _practiceCountingSequence,
            tooltip: 'Practice Counting 1-10',
          ),
        ],
      ),
      body: _numberContents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with current number display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade100, Colors.purple.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _numberContents[_currentIndex].letter,
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      Text(
                        _numberContents[_currentIndex].word,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pronunciation: ${_numberContents[_currentIndex].pronunciation}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.indigo.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Control buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isPlaying ? null : () => _speakNumber(_numberContents[_currentIndex]),
                        icon: Icon(_isPlaying ? Icons.volume_off : Icons.volume_up),
                        label: Text(_isPlaying ? 'Speaking...' : 'Say Number'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _currentIndex > 0 ? () {
                          setState(() => _currentIndex--);
                        } : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _currentIndex < _numberContents.length - 1 ? () {
                          setState(() => _currentIndex++);
                        } : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Fun fact section
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.yellow.shade200, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.amber.shade600, size: 28),
                            const SizedBox(width: 8),
                            const Text(
                              'Did You Know?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _numberContents[_currentIndex].funFact,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Interactive counting game
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 400, // Fixed height to prevent overflow
                    child: const CountingGameWidget(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Number grid for quick navigation
                Container(
                  height: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _numberContents.length,
                    itemBuilder: (context, index) {
                      final content = _numberContents[index];
                      final isSelected = index == _currentIndex;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() => _currentIndex = index);
                          _speakNumber(content);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade200 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  content.letter,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                  ),
                                ),
                                Text(
                                  content.word,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected ? Colors.blue.shade700 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
