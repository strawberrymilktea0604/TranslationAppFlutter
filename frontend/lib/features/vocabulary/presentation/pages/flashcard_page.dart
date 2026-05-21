import 'package:flutter/material.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_entity.dart';

class FlashcardPage extends StatefulWidget {
  final List<VocabularyEntity> vocabularyList;

  const FlashcardPage({super.key, required this.vocabularyList});

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  void _nextCard() {
    if (_currentIndex < widget.vocabularyList.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vocabularyList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ôn tập Flashcard')),
        body: const Center(child: Text('Không có từ vựng nào để ôn tập.')),
      );
    }

    final entry = widget.vocabularyList[_currentIndex];
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1} / ${widget.vocabularyList.length}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flashcard
              Expanded(
                child: GestureDetector(
                  onTap: _flipCard,
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! > 300) {
                      _prevCard();
                    } else if (details.primaryVelocity! < -300) {
                      _nextCard();
                    }
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      final rotate = Tween(begin: 3.14159, end: 0.0).animate(animation);
                      return AnimatedBuilder(
                        animation: rotate,
                        child: child,
                        builder: (context, child) {
                          final angle = rotate.value;
                          final transform = Matrix4.rotationY(angle);
                          return Transform(
                            transform: transform,
                            alignment: Alignment.center,
                            child: angle > 1.57 ? const SizedBox() : child,
                          );
                        },
                      );
                    },
                    child: Container(
                      key: ValueKey(_isFlipped),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _isFlipped ? cs.primaryContainer : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isFlipped ? entry.translation : entry.word,
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _isFlipped ? cs.onPrimaryContainer : cs.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TtsIconButton(
                            text: _isFlipped ? entry.translation : entry.word,
                            languageCode: _isFlipped ? entry.targetLanguage : entry.sourceLanguage,
                            tooltip: 'Phát âm',
                            iconSize: 32,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _isFlipped ? 'Chạm để lùi mặt trước' : 'Chạm để xem nghĩa',
                            style: textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    onPressed: _currentIndex > 0 ? _prevCard : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                    iconSize: 32,
                    padding: const EdgeInsets.all(16),
                  ),
                  IconButton.filled(
                    onPressed: _currentIndex < widget.vocabularyList.length - 1
                        ? _nextCard
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    iconSize: 32,
                    padding: const EdgeInsets.all(16),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
