import 'package:flutter/material.dart';
import '../modules/learning_model.dart';
import '../modules/education_content.dart';
import '../utils/tts_service.dart';

class ModelDetailPage extends StatefulWidget {
  final LearningModel model;

  const ModelDetailPage({
    super.key,
    required this.model,
  });

  @override
  State<ModelDetailPage> createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage> {
  List<AlphabetContent> _contentItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() {
    setState(() {
      _isLoading = true;
    });

    // Get the content items based on the model name
    _contentItems = getContentsByModelName(widget.model.name);

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.model.name),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contentItems.isEmpty
              ? _buildEmptyState()
              : _buildContentGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No content available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any content for this model',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _contentItems.length,
      itemBuilder: (context, index) {
        final item = _contentItems[index];
        return _buildContentCard(item);
      },
    );
  }

  Widget _buildContentCard(AlphabetContent item) {
    return GestureDetector(
      onTap: () => _showDetailDialog(item),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.asset(
                  item.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported,
                          size: 50, color: Colors.grey[400]),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    '${item.letter} - ${item.word}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to learn more',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(AlphabetContent item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        '${item.letter} is for ${item.word}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          item.imagePath,
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: Icon(Icons.image_not_supported,
                                  size: 50, color: Colors.grey[400]),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildInfoSection('Pronunciation', item.pronunciation),
                      _buildInfoSection(
                        'Fun Fact',
                        item.funFact,
                      ),
                      const SizedBox(height: 24),
                      // Enhanced pronunciation teaching for numbers
                      if (widget.model.name == 'Numbers & Counting')
                        Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  // First speak the number
                                  await TtsService().speak(item.word);
                                  await Future.delayed(const Duration(milliseconds: 500));
                                  
                                  // Then speak the pronunciation guide
                                  await TtsService().speak('Let me say it slowly: ${item.pronunciation}');
                                  await Future.delayed(const Duration(milliseconds: 500));
                                  
                                  // Finally speak the fun fact
                                  await TtsService().speak(item.funFact);
                                } catch (e) {
                                  debugPrint('TTS speak error (numbers): $e');
                                }
                              },
                              icon: const Icon(
                                Icons.volume_up,
                                color: Colors.white,
                              ),
                              label: const Text('Learn Pronunciation'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await TtsService().speak('${item.word}. ${item.pronunciation}');
                                } catch (e) {
                                  debugPrint('TTS speak error (quick): $e');
                                }
                              },
                              icon: const Icon(
                                Icons.repeat,
                                color: Colors.white,
                              ),
                              label: const Text('Quick Practice'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
                              ),
                            ),
                          ],
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final phrase = item.letter.isNotEmpty
                                  ? '${item.letter} is for ${item.word}'
                                  : item.word;
                              await TtsService().speak(phrase);
                            } catch (e) {
                              debugPrint('TTS speak error (detail): $e');
                            }
                          },
                          icon: const Icon(
                            Icons.volume_up,
                            color: Colors.white,
                          ),
                          label: const Text('Hear Pronunciation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Note: We're using the getContentsByModelName function from education_content.dart
}
