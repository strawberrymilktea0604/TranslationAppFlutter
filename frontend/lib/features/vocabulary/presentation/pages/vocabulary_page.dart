import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart';
import 'package:frontend/features/history/presentation/bloc/history_cubit.dart';
import 'package:frontend/features/history/presentation/bloc/history_state.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_entity.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_state.dart';
import 'package:frontend/injection_container.dart';

/// UC07 — Vocabulary page with two tabs:
/// - Tab 0: Lịch sử từ vựng (translation history, offline-first via Isar)
/// - Tab 1: Từ vựng đã lưu (saved vocabulary, offline-first via Isar)
///
/// Both tabs use BlocBuilder + ListView.builder (copilot-instructions §3.4).
class VocabularyPage extends StatelessWidget {
  const VocabularyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HistoryCubit>(
          create: (_) => sl<HistoryCubit>()..loadHistory(),
        ),
      ],
      child: const _VocabularyTabView(),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab scaffold
// ---------------------------------------------------------------------------

class _VocabularyTabView extends StatefulWidget {
  const _VocabularyTabView();

  @override
  State<_VocabularyTabView> createState() => _VocabularyTabViewState();
}

class _VocabularyTabViewState extends State<_VocabularyTabView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Tab bar — sits inside the page body, not inside an AppBar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Lịch sử dịch'),
              Tab(text: 'Từ đã lưu'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _HistoryTab(),
              _SavedVocabTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Tab 0 — Translation history (HistoryCubit)
// ===========================================================================

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<HistoryCubit, HistoryState>(
      listener: (context, state) {
        if (state is HistoryDeleteSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã xóa lịch sử'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          context.read<HistoryCubit>().loadHistory();
        }
        if (state is HistoryClearSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã xóa toàn bộ lịch sử'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          context.read<HistoryCubit>().loadHistory();
        }
      },
      builder: (context, state) {
        if (state is HistoryLoading || state is HistoryInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is HistoryFailure) {
          return _ErrorState(
            cs: cs,
            textTheme: textTheme,
            message: state.message,
            onRetry: () => context.read<HistoryCubit>().loadHistory(),
          );
        }
        if (state is HistoryLoaded) {
          if (state.historyList.isEmpty) {
            return _EmptyHistoryState(cs: cs, textTheme: textTheme);
          }
          return _HistoryListView(items: state.historyList);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme textTheme;
  const _EmptyHistoryState({required this.cs, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: cs.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có lịch sử dịch',
            style: textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lịch sử các bản dịch sẽ hiển thị ở đây',
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryListView extends StatelessWidget {
  final List<HistoryEntity> items;
  const _HistoryListView({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final entry = items[index];
        return _HistoryCard(entry: entry, cs: cs, textTheme: textTheme);
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntity entry;
  final ColorScheme cs;
  final TextTheme textTheme;

  const _HistoryCard({
    required this.entry,
    required this.cs,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(entry.createdAt.toLocal());
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
            // Source text
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.sourceText,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Sync status
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
              entry.translatedText,
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
                // Language pair chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2,
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
                const SizedBox(width: 8),
                // Date
                Text(
                  dateStr,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                // TTS
                TtsIconButton(
                  text: entry.sourceText,
                  languageCode: entry.sourceLanguage,
                  tooltip: 'Phát âm',
                  iconSize: 18,
                ),
                // Delete
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
        title: const Text('Xóa lịch sử'),
        content: Text(
          'Bạn có chắc muốn xóa bản dịch "${entry.sourceText.length > 30 ? '${entry.sourceText.substring(0, 30)}...' : entry.sourceText}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<HistoryCubit>().deleteHistory(entry.isarId);
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

// ===========================================================================
// Tab 1 — Saved vocabulary (VocabularyCubit, already provided at shell level)
// ===========================================================================

class _SavedVocabTab extends StatelessWidget {
  const _SavedVocabTab();

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
                ? _EmptyVocabState(cs: cs, textTheme: textTheme)
                : _VocabularyListView(items: list),
          VocabularyFailure(message: final msg) => _ErrorState(
              cs: cs,
              textTheme: textTheme,
              message: msg,
              onRetry: () => context.read<VocabularyCubit>().loadVocabularyList(),
            ),
          // Initial / Saving / SaveSuccess / DeleteSuccess
          _ => const Center(child: CircularProgressIndicator()),
        };
      },
    );
  }
}

class _EmptyVocabState extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme textTheme;
  const _EmptyVocabState({required this.cs, required this.textTheme});

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
                  .deleteVocabulary(entry.isarId);
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

// ---------------------------------------------------------------------------
// Shared error state widget
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme textTheme;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.cs,
    required this.textTheme,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text(message,
              style: textTheme.bodyMedium?.copyWith(color: cs.error)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
