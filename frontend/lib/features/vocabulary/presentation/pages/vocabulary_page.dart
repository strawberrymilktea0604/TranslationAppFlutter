import 'package:flutter/material.dart';

/// Placeholder page for the Vocabulary feature.
///
/// UC07 — Lưu từ vựng. Displays saved vocabulary list.
/// Data is read from local Isar DB first (offline-first).
///
/// Will be replaced with full implementation using:
/// - `BlocBuilder<VocabularyCubit, VocabularyState>`
/// - ListView.builder for large lists (copilot-instructions §3.4)
class VocabularyPlaceholderPage extends StatelessWidget {
  const VocabularyPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ vựng'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Tìm kiếm',
            onPressed: () {
              // TODO: Implement vocabulary search
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có từ vựng nào',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lưu từ vựng khi dịch để ôn tập sau',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
