import 'package:flutter/material.dart';

/// Placeholder page for the Translation feature.
///
/// This is the main tab of the application — UC01 (Dịch văn bản thuần),
/// UC02 (Chuyển đổi ngôn ngữ), UC03 (Phát âm văn bản TTS).
///
/// Will be replaced with the full TranslationPage implementation
/// that includes:
/// - `BlocBuilder<TranslationCubit, TranslationState>` with exhaustive switch
/// - Debounce (500ms) on translation input (copilot-instructions §3.4)
/// - Language selector
/// - Voice input (UC05) and image input (UC06) buttons
class TranslationPlaceholderPage extends StatelessWidget {
  const TranslationPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch thuật'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_outlined),
            tooltip: 'Dịch bằng giọng nói',
            onPressed: () {
              // TODO: Navigate to Speech-to-Text (UC05)
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Dịch bằng hình ảnh',
            onPressed: () {
              // TODO: Navigate to OCR (UC06)
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Language selector row
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tiếng Anh',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.swap_horiz,
                        color: colorScheme.primary,
                      ),
                      onPressed: () {
                        // TODO: Implement language swap (UC02)
                      },
                    ),
                    Text(
                      'Tiếng Việt',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Source text input
            Expanded(
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhập văn bản',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          maxLines: null,
                          expands: true,
                          textAlignVertical:
                              TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText:
                                'Nhập văn bản cần dịch...',
                            border: InputBorder.none,
                          ),
                          onChanged: (_) {
                            // TODO: Debounce 500ms then call
                            // TranslationCubit.translate()
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(
                                Icons.volume_up_outlined),
                            tooltip: 'Phát âm (TTS)',
                            onPressed: () {
                              // TODO: Implement TTS (UC03)
                            },
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.copy_outlined),
                            tooltip: 'Sao chép',
                            onPressed: () {
                              // TODO: Copy text to clipboard
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Translation result area
            Expanded(
              child: Card(
                elevation: 0,
                color: colorScheme.primaryContainer
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bản dịch',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Bản dịch sẽ xuất hiện ở đây',
                            style:
                                textTheme.bodyLarge?.copyWith(
                              color:
                                  colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                                Icons.bookmark_border),
                            tooltip: 'Lưu từ vựng',
                            onPressed: () {
                              // TODO: Save to vocabulary (UC07)
                            },
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.volume_up_outlined),
                                tooltip: 'Phát âm (TTS)',
                                onPressed: () {
                                  // TODO: TTS for result
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.copy_outlined),
                                tooltip: 'Sao chép',
                                onPressed: () {
                                  // TODO: Copy translation
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
