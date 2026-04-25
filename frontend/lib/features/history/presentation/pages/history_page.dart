import 'package:flutter/material.dart';

/// Placeholder page for the History feature.
///
/// UC08 — Tra cứu lịch sử. Displays translation history.
/// Data is read from local Isar DB first (offline-first).
///
/// Will be replaced with full implementation using:
/// - `BlocBuilder<HistoryCubit, HistoryState>`
/// - ListView.builder for large lists (copilot-instructions §3.4)
class HistoryPlaceholderPage extends StatelessWidget {
  const HistoryPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Tìm kiếm',
            onPressed: () {
              // TODO: Implement history search
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Xóa tất cả',
            onPressed: () {
              // TODO: Implement clear all history
              // Must use soft delete (isDeleted = true)
              // per copilot-instructions §5.4
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử dịch',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lịch sử dịch sẽ hiển thị ở đây',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
