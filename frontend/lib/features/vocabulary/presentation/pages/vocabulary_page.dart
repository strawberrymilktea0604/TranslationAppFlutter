import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_entity.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_state.dart';

/// UC07 — Vocabulary page. Displays saved vocabulary list.
///
/// Data is read from local Isar DB first (offline-first).
/// Uses `BlocBuilder<VocabularyCubit, VocabularyState>`
/// and `ListView.builder` for large lists (copilot-instructions §3.4).
class VocabularyPage extends StatelessWidget {
  const VocabularyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<VocabularyCubit, VocabularyState>(
      builder: (context, state) {
        return switch (state) {
          VocabularyLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          VocabularyLoaded(vocabularyList: final list) =>
            list.isEmpty
                ? _EmptyState(cs: cs, textTheme: textTheme)
                : _VocabularyListView(items: list),
          VocabularyFailure(message: final msg) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: cs.error),
                  const SizedBox(height: 12),
                  Text(msg,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: cs.error)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context
                        .read<VocabularyCubit>()
                        .loadVocabularyList(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          // Initial / Saving / SaveSuccess / DeleteSuccess
          // — show loading to auto-refresh.
          _ => const Center(child: CircularProgressIndicator()),
        };
      },
    );
  }
}

/// Empty state widget when no vocabulary entries exist.
class _EmptyState extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme textTheme;

  const _EmptyState({required this.cs, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: cs.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có từ vựng nào',
            style: textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lưu từ vựng khi dịch để ôn tập sau',
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vocabulary list using ListView.builder for performance (§3.4).
class _VocabularyListView extends StatelessWidget {
  final List<VocabularyEntity> items;

  const _VocabularyListView({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocListener<VocabularyCubit, VocabularyState>(
      listener: (context, state) {
        if (state is VocabularyDeleteSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã xóa từ vựng'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          context.read<VocabularyCubit>().loadVocabularyList();
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final entry = items[index];
          return _VocabularyCard(
            entry: entry,
            cs: cs,
            textTheme: textTheme,
          );
        },
      ),
    );
  }
}

/// Card widget for a single vocabulary entry.
class _VocabularyCard extends StatelessWidget {
  final VocabularyEntity entry;
  final ColorScheme cs;
  final TextTheme textTheme;

  const _VocabularyCard({
    required this.entry,
    required this.cs,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source word
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.word,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Sync status indicator
                if (!entry.isSynced)
                  Tooltip(
                    message: 'Chưa đồng bộ',
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Translation
            Text(
              entry.translation,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.primaryColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Action bar
            Row(
              children: [
                // Language pair label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entry.sourceLanguage.toUpperCase()} → '
                    '${entry.targetLanguage.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                const Spacer(),
                // TTS button for the source word
                TtsIconButton(
                  text: entry.word,
                  languageCode: entry.sourceLanguage,
                  tooltip: 'Phát âm',
                  iconSize: 18,
                ),
                // Delete button (soft-delete)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Xóa',
                  color: cs.error.withValues(alpha: 0.7),
                  onPressed: () => _confirmDelete(context),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa từ vựng'),
        content: Text('Bạn có chắc muốn xóa "${entry.word}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<VocabularyCubit>()
                  .deleteVocabulary(entry.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
