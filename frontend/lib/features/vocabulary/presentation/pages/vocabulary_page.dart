import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:frontend/core/theme/app_theme.dart';
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
/// - Tab 0: Translation history (offline-first via Isar)
/// - Tab 1: Saved vocabulary (offline-first via Isar)
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
                margin: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
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
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('History'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.style_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Flashcards'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
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
                    tooltip: 'Sync',
                    onPressed: isSyncing
                        ? null
                        : () {
                            context.read<SyncCubit>().requestSync();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Syncing data...'),
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
// Tab 0 — Translation history (HistoryCubit) with search bar per wireframe
// ===========================================================================

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<HistoryCubit>().loadHistory(
        searchQuery: query.trim().isEmpty ? null : query.trim(),
      );
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<HistoryCubit>().loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // ── Search bar (matching wireframe) ────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search history',
                hintStyle: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  size: 20,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      onPressed: _clearSearch,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    );
                  },
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
        // ── History list ────────────────────────────────────────────────
        Expanded(
          child: BlocConsumer<HistoryCubit, HistoryState>(
            listener: (context, state) {
              if (state is HistoryDeleteSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('History deleted'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.successColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
                context.read<HistoryCubit>().loadHistory(
                  searchQuery: _searchController.text.trim().isEmpty
                      ? null
                      : _searchController.text.trim(),
                );
              }
              if (state is HistoryClearSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All history deleted'),
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
                  // Show different message if searching vs empty
                  if (_searchController.text.trim().isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 72,
                            color: cs.primary.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No results found',
                            style: textTheme.titleMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different keyword',
                            style: textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return _EmptyHistoryState(cs: cs, textTheme: textTheme);
                }
                return _HistoryListView(items: state.historyList);
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ],
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
            size: 72,
            color: cs.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 20),
          Text(
            'No translation history',
            style: textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Translations will appear here',
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
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
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
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
    return Dismissible(
      key: ValueKey(entry.isarId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.delete_rounded, color: cs.error),
      ),
      confirmDismiss: (_) => _confirmDeleteSwipe(context),
      onDismissed: (_) {
        context.read<HistoryCubit>().deleteHistory(entry.isarId);
      },
      child: Column(
        children: [
          InkWell(
            onTap: () => _showDetailSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Main content — source + translation (wireframe layout)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Source text — main question
                        Text(
                          entry.sourceText,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Translation text — answer
                        Text(
                          entry.translatedText,
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Star/Save button (matching wireframe) — right aligned
                  GestureDetector(
                    onTap: () {
                      showSaveVocabularyDialog(
                        context: context,
                        cubit: context.read<VocabularyCubit>(),
                        word: entry.sourceText,
                        translation: entry.translatedText,
                        sourceLanguage: entry.sourceLanguage,
                        targetLanguage: entry.targetLanguage,
                      );
                    },
                    child: Tooltip(
                      message: 'Lưu từ vựng',
                      child: Icon(
                        Icons.star_outline_rounded,
                        size: 24,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteSwipe(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete history?'),
        content: Text(
          'Are you sure you want to delete "${entry.sourceText.length > 30 ? '${entry.sourceText.substring(0, 30)}...' : entry.sourceText}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Shows a bottom sheet with full detail of the history entry.
  void _showDetailSheet(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(entry.createdAt.toLocal());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Language pair + date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.sourceLanguage.toUpperCase()} → '
                        '${entry.targetLanguage.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      entry.isSynced
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      size: 16,
                      color: entry.isSynced
                          ? cs.primary.withValues(alpha: 0.7)
                          : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Source text
                Text(
                  entry.sourceText,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                // Translation
                Text(
                  entry.translatedText,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Save vocabulary
                    _DetailAction(
                      icon: Icons.bookmark_add_outlined,
                      label: 'Save word',
                      color: AppTheme.secondaryColor,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        showSaveVocabularyDialog(
                          context: context,
                          cubit: context.read<VocabularyCubit>(),
                          word: entry.sourceText,
                          translation: entry.translatedText,
                          sourceLanguage: entry.sourceLanguage,
                          targetLanguage: entry.targetLanguage,
                        );
                      },
                    ),
                    // TTS
                    _DetailAction(
                      icon: Icons.volume_up_rounded,
                      label: 'Speak',
                      color: cs.primary,
                      onTap: () {
                        Navigator.of(ctx).pop();
                      },
                    ),
                    // Copy
                    _DetailAction(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      color: cs.primary,
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: '${entry.sourceText}\n${entry.translatedText}'),
                        );
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    // Delete
                    _DetailAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: cs.error,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        context.read<HistoryCubit>().deleteHistory(entry.isarId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail action button for bottom sheet
// ---------------------------------------------------------------------------

class _DetailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DetailAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 72,
              color: cs.error.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              'Oops! Something went wrong',
              style: textTheme.titleMedium?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
// End of file.
