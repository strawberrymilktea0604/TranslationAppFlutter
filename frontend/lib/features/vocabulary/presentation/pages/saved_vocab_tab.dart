import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_category_entity.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_state.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_state.dart';
import 'package:frontend/features/vocabulary/presentation/pages/flashcard_page.dart';
import 'package:frontend/injection_container.dart';

class SavedVocabTab extends StatelessWidget {
  const SavedVocabTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<VocabularyCategoryCubit>()..loadCategories(),
      child: const _CategoryListWidget(),
    );
  }
}

class _CategoryListWidget extends StatelessWidget {
  const _CategoryListWidget();

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm danh mục'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<VocabularyCategoryCubit>().createCategory(newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent, // To blend with tab view
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo danh mục'),
      ),
      body: BlocConsumer<VocabularyCategoryCubit, VocabularyCategoryState>(
        listener: (context, state) {
          if (state is VocabularyCategoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: cs.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is VocabularyCategoryLoading || state is VocabularyCategoryInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is VocabularyCategoryLoaded) {
            final categories = state.categories;
            if (categories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.category_rounded, size: 80, color: cs.primary.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('Chưa có danh mục nào', style: textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text('Lưu từ vựng để tạo danh mục mới', style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100), // padding bottom for fab
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _CategoryCard(category: cat, cs: cs, textTheme: textTheme);
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final VocabularyCategoryEntity category;
  final ColorScheme cs;
  final TextTheme textTheme;

  const _CategoryCard({required this.category, required this.cs, required this.textTheme});

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên danh mục'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<VocabularyCategoryCubit>().updateCategory(category.id, newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa danh mục'),
        content: Text('Bạn có chắc muốn xóa danh mục "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              context.read<VocabularyCategoryCubit>().deleteCategory(category.id);
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _openCategoryDetails(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CategoryDetailScreen(category: category),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openCategoryDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.folder_special_rounded, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Tooltip(
                          message: category.isSynced
                              ? 'Đã sao lưu lên database'
                              : 'Chưa đồng bộ (offline)',
                          child: Icon(
                            category.isSynced
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                            size: 13,
                            color: category.isSynced
                                ? cs.primary.withValues(alpha: 0.7)
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          category.isSynced
                              ? 'Đã sao lưu'
                              : 'Chưa đồng bộ',
                          style: textTheme.bodySmall?.copyWith(
                            color: category.isSynced
                                ? cs.primary.withValues(alpha: 0.7)
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'rename') {
                    _showRenameDialog(context);
                  } else if (value == 'delete') {
                    _confirmDelete(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Đổi tên'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: cs.error, size: 18),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: cs.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDetailScreen extends StatelessWidget {
  final VocabularyCategoryEntity category;

  const _CategoryDetailScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<VocabularyCubit>()..loadVocabularyList(category: category.name),
      child: Scaffold(
        appBar: AppBar(
          title: Text(category.name),
        ),
        body: BlocBuilder<VocabularyCubit, VocabularyState>(
          builder: (context, state) {
            if (state is VocabularyLoaded) {
              final list = state.vocabularyList;
              if (list.isEmpty) {
                return const Center(child: Text('Chưa có từ vựng nào trong danh mục này.'));
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final entry = list[index];
                        final cs = Theme.of(context).colorScheme;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              entry.word,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.translation,
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Tooltip(
                                      message: entry.isSynced
                                          ? 'Đã sao lưu lên database'
                                          : 'Chưa đồng bộ (offline)',
                                      child: Icon(
                                        entry.isSynced
                                            ? Icons.cloud_done_outlined
                                            : Icons.cloud_off_outlined,
                                        size: 12,
                                        color: entry.isSynced
                                            ? cs.primary.withValues(alpha: 0.7)
                                            : cs.onSurfaceVariant
                                                .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      entry.isSynced
                                          ? 'Đã sao lưu'
                                          : 'Chưa đồng bộ',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: entry.isSynced
                                            ? cs.primary.withValues(alpha: 0.7)
                                            : cs.onSurfaceVariant
                                                .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                context
                                    .read<VocabularyCubit>()
                                    .deleteVocabulary(entry.isarId);
                                context
                                    .read<VocabularyCubit>()
                                    .loadVocabularyList(
                                      category: category.name,
                                    );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FlashcardPage(vocabularyList: list),
                            ),
                          );
                        },
                        icon: const Icon(Icons.style_rounded),
                        label: const Text('Reviewing Flashcards'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
