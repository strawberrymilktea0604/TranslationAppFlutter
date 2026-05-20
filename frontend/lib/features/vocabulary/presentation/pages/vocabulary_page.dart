import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart';
import 'package:frontend/features/history/presentation/bloc/history_cubit.dart';
import 'package:frontend/features/history/presentation/bloc/history_state.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/pages/saved_vocab_tab.dart';
import 'package:frontend/features/vocabulary/presentation/widgets/save_vocabulary_dialog.dart';
import 'package:frontend/features/sync/presentation/bloc/sync_cubit.dart';
import 'package:frontend/features/sync/presentation/bloc/sync_state.dart';
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
        Row(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 8, 4),
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
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 4),
              child: BlocBuilder<SyncCubit, SyncState>(
                builder: (context, state) {
                  final isSyncing = state is SyncSyncing;
                  return IconButton.filledTonal(
                    icon: isSyncing 
                        ? const SizedBox(
                            width: 18, height: 18, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          ) 
                        : const Icon(Icons.sync_rounded),
                    tooltip: 'Đồng bộ',
                    onPressed: isSyncing
                        ? null
                        : () {
                            context.read<SyncCubit>().requestSync();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đang đồng bộ dữ liệu...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                  );
                },
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _HistoryTab(),
              SavedVocabTab(),
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
                // Sync status icon
                Tooltip(
                  message: entry.isSynced ? 'Đã sao lưu' : 'Chưa đồng bộ',
                  child: Icon(
                    entry.isSynced
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    size: 16,
                    color: entry.isSynced
                        ? cs.primary.withValues(alpha: 0.7)
                        : cs.onSurfaceVariant.withValues(alpha: 0.5),
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
                Expanded(
                  child: Text(
                    dateStr,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Save to vocabulary
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  tooltip: 'Lưu từ vựng',
                  color: AppTheme.secondaryColor,
                  onPressed: () {
                    showSaveVocabularyDialog(
                      context: context,
                      cubit: context.read<VocabularyCubit>(),
                      word: entry.sourceText,
                      translation: entry.translatedText,
                      sourceLanguage: entry.sourceLanguage,
                      targetLanguage: entry.targetLanguage,
                    );
                  },
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
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
// End of file.
