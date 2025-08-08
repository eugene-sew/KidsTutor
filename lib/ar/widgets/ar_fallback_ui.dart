import 'package:flutter/material.dart';
import '../models/ar_model.dart';
import '../models/ar_model_mapping.dart';

/// Fallback UI component for when AR is not available or fails
class ARFallbackUI extends StatefulWidget {
  /// List of object recognitions from the ML model
  final List<Map<String, dynamic>> recognitions;

  /// Callback when a model is interacted with
  final Function(ARModel model)? onModelInteraction;

  /// Reason for fallback
  final String fallbackReason;

  /// Whether to show retry option
  final bool showRetry;

  /// Callback for retry action
  final VoidCallback? onRetry;

  const ARFallbackUI({
    Key? key,
    required this.recognitions,
    this.onModelInteraction,
    required this.fallbackReason,
    this.showRetry = false,
    this.onRetry,
  }) : super(key: key);

  @override
  State<ARFallbackUI> createState() => _ARFallbackUIState();
}

class _ARFallbackUIState extends State<ARFallbackUI>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeAnimationController;
  late AnimationController _scaleAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Currently displayed model
  ARModel? _currentModel;
  String? _currentLetter;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _fadeAnimationController.forward();
    _scaleAnimationController.forward();

    // Update model from recognitions
    _updateModelFromRecognitions();
  }

  @override
  void didUpdateWidget(ARFallbackUI oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update model when recognitions change
    if (widget.recognitions != oldWidget.recognitions) {
      _updateModelFromRecognitions();
    }
  }

  /// Update the displayed model based on recognitions
  void _updateModelFromRecognitions() {
    if (widget.recognitions.isEmpty) {
      setState(() {
        _currentModel = null;
        _currentLetter = null;
      });
      return;
    }

    // Get the top recognition
    final topRecognition = widget.recognitions.first;
    final letterLabel = _extractLetterFromLabel(topRecognition['label'] ?? '');
    final confidence = topRecognition['confidence'] ?? 0.0;

    // Only proceed if we have a letter and confidence is high enough
    if (letterLabel.isNotEmpty && confidence > 0.65) {
      // Get the model for this letter
      final model = ARModelMapping().getModelForLetter(letterLabel);
      if (model != null && model != _currentModel) {
        setState(() {
          _currentModel = model;
          _currentLetter = letterLabel;
        });

        // Animate the model change
        _scaleAnimationController.reset();
        _scaleAnimationController.forward();
      }
    }
  }

  /// Extract the letter from a label string (e.g. "1 A" -> "A")
  String _extractLetterFromLabel(String label) {
    final parts = label.split(' ');
    if (parts.length > 1) {
      return parts[1];
    }
    return '';
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _scaleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[900]!,
                  Colors.grey[800]!,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Background pattern
                _buildBackgroundPattern(),

                // Main content
                if (_currentModel != null)
                  _buildModelDisplay()
                else
                  _buildEmptyState(),

                // Fallback notice
                _buildFallbackNotice(),

                // Retry button if available
                if (widget.showRetry && widget.onRetry != null)
                  _buildRetryButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build background pattern
  Widget _buildBackgroundPattern() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _BackgroundPatternPainter(),
      ),
    );
  }

  /// Build the model display
  Widget _buildModelDisplay() {
    if (_currentModel == null || _currentLetter == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Center(
            child: GestureDetector(
              onTap: () => _handleModelTap(_currentModel!),
              child: Container(
                margin: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Letter display
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentLetter!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Model information card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Model name
                          Text(
                            _currentModel!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Pronunciation
                          Text(
                            'Pronunciation: ${_currentModel!.pronunciation}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),

                          // Fun fact if available
                          if (_currentModel!.funFact != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _currentModel!.funFact!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Tap instruction
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Tap to learn more',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build empty state when no model is detected
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Show an object to the camera',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Point your camera at letters or objects to learn about them',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Build fallback notice
  Widget _buildFallbackNotice() {
    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'AR Mode Unavailable',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    widget.fallbackReason,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
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

  /// Build retry button
  Widget _buildRetryButton() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Center(
        child: ElevatedButton.icon(
          onPressed: widget.onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try AR Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      ),
    );
  }

  /// Handle model tap
  void _handleModelTap(ARModel model) {
    // Show detailed information
    _showModelDetails(model);

    // Call the interaction callback if provided
    if (widget.onModelInteraction != null) {
      widget.onModelInteraction!(model);
    }
  }

  /// Show detailed model information
  void _showModelDetails(ARModel model) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(model.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pronunciation: ${model.pronunciation}',
                style: const TextStyle(fontSize: 16),
              ),
              if (model.funFact != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Fun Fact:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  model.funFact!,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enable AR in settings to see 3D models!',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter for background pattern
class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Draw grid pattern
    const spacing = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
