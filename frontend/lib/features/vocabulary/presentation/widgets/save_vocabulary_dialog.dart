import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_state.dart';
import 'package:frontend/injection_container.dart';

/// Shows a dialog to save vocabulary with a category selection.
///
/// Rules:
/// - Nút "Lưu" chỉ bật khi đã chọn một danh mục (chip).
/// - Nút "+ Tạo danh mục" mở AlertDialog phụ; sau khi tạo xong,
///   chip mới được auto-select và nút "Lưu" được bật.
Future<void> showSaveVocabularyDialog({
  required BuildContext context,
  required VocabularyCubit cubit,
  required String word,
  required String translation,
  required String sourceLanguage,
  required String targetLanguage,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => BlocProvider(
      create: (_) => sl<VocabularyCategoryCubit>()..loadCategories(),
      child: _SaveVocabularyDialogContent(
        cubit: cubit,
        word: word,
        translation: translation,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Internal StatefulWidget — owns selectedCategoryId / selectedCategoryName
// ---------------------------------------------------------------------------

class _SaveVocabularyDialogContent extends StatefulWidget {
  final VocabularyCubit cubit;
  final String word;
  final String translation;
  final String sourceLanguage;
  final String targetLanguage;

  const _SaveVocabularyDialogContent({
    required this.cubit,
    required this.word,
    required this.translation,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  State<_SaveVocabularyDialogContent> createState() =>
      _SaveVocabularyDialogContentState();
}

class _SaveVocabularyDialogContentState
    extends State<_SaveVocabularyDialogContent> {
  String? _selectedCategoryName;
  int? _selectedCategoryId;

  bool get _canSave =>
      _selectedCategoryName != null && _selectedCategoryName!.isNotEmpty;

  /// Mở AlertDialog phụ để nhập tên danh mục mới.
  /// Sau khi tạo thành công → reload + auto-select chip mới.
  Future<void> _showCreateCategoryDialog() async {
    final controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo danh mục mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            final name = v.trim();
            if (name.isNotEmpty) Navigator.of(ctx).pop(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    // Tạo danh mục → cubit sẽ emit VocabularyCategoryLoaded với list mới.
    // Auto-select được xử lý trong BlocListener bên dưới.
    if (!mounted) return;
    context
        .read<VocabularyCategoryCubit>()
        .createCategory(newName);

    // Lưu tạm tên để auto-select sau khi state cập nhật.
    setState(() {
      _selectedCategoryName = newName;
      _selectedCategoryId = null; // ID thực sẽ được gán sau khi reload
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VocabularyCategoryCubit, VocabularyCategoryState>(
      listener: (context, state) {
        // Sau khi tạo danh mục, danh sách được reload.
        // Tìm category có tên trùng và gán ID thực.
        if (state is VocabularyCategoryLoaded &&
            _selectedCategoryName != null &&
            _selectedCategoryId == null) {
          final match = state.categories.where(
            (c) => c.name == _selectedCategoryName,
          );
          if (match.isNotEmpty) {
            setState(() => _selectedCategoryId = match.first.id);
          }
        }
        if (state is VocabularyCategoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: AlertDialog(
        title: const Text('Lưu từ vựng'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Từ: ${widget.word}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Nghĩa: ${widget.translation}'),
              const SizedBox(height: 16),
              // Header row: "Chọn danh mục" + nút tạo mới
              Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Chọn danh mục:',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showCreateCategoryDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Tạo danh mục'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Category chips
              BlocBuilder<VocabularyCategoryCubit, VocabularyCategoryState>(
                builder: (context, state) {
                  if (state is VocabularyCategoryLoading) {
                    return const SizedBox(
                      height: 32,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (state is VocabularyCategoryLoaded) {
                    final categories = state.categories;
                    if (categories.isEmpty) {
                      return Text(
                        'Chưa có danh mục nào. Nhấn "Tạo danh mục" để bắt đầu.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id ||
                            (_selectedCategoryId == null &&
                                _selectedCategoryName == cat.name);
                        return ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategoryName = cat.name;
                                _selectedCategoryId = cat.id;
                              });
                            }
                          },
                        );
                      }).toList(),
                    );
                  }
                  return Text(
                    'Không tải được danh mục.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          // Nút Lưu: disabled khi chưa chọn danh mục
          FilledButton(
            onPressed: _canSave
                ? () {
                    widget.cubit.saveVocabulary(
                      word: widget.word,
                      translation: widget.translation,
                      sourceLanguage: widget.sourceLanguage,
                      targetLanguage: widget.targetLanguage,
                      category: _selectedCategoryName!,
                      categoryId: _selectedCategoryId,
                    );
                    Navigator.of(context).pop();
                  }
                : null,
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
