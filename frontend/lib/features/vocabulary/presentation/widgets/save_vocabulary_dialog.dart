import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_state.dart';
import 'package:frontend/injection_container.dart';

/// Shows a dialog to save vocabulary with a category selection.
Future<void> showSaveVocabularyDialog({
  required BuildContext context,
  required VocabularyCubit cubit,
  required String word,
  required String translation,
  required String sourceLanguage,
  required String targetLanguage,
}) async {
  String selectedCategoryName = 'Chưa phân loại';
  int? selectedCategoryId;
  final categoryController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return BlocProvider(
        create: (_) => sl<VocabularyCategoryCubit>()..loadCategories(),
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Lưu từ vựng'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Từ: $word', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Nghĩa: $translation'),
                    const SizedBox(height: 16),
                    const Text('Chọn danh mục:'),
                    const SizedBox(height: 8),
                    BlocBuilder<VocabularyCategoryCubit, VocabularyCategoryState>(
                      builder: (context, state) {
                        if (state is VocabularyCategoryLoading) {
                          return const CircularProgressIndicator();
                        } else if (state is VocabularyCategoryLoaded) {
                          final categories = state.categories;
                          if (categories.isEmpty) {
                            return const Text('Chưa có danh mục nào. Hãy tạo mới bên dưới.');
                          }
                          return Wrap(
                            spacing: 8,
                            children: categories.map((cat) {
                              final isSelected = selectedCategoryId == cat.id || 
                                  (selectedCategoryId == null && selectedCategoryName == cat.name);
                              return ChoiceChip(
                                label: Text(cat.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      selectedCategoryName = cat.name;
                                      selectedCategoryId = cat.id;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          );
                        } else {
                          return const Text('Không tải được danh mục.');
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Hoặc tạo danh mục mới:'),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tên danh mục mới',
                        isDense: true,
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          setState(() {
                            selectedCategoryName = val;
                            selectedCategoryId = null; // Tự tạo mới thì chưa có ID
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Hủy'),
                ),
                BlocBuilder<VocabularyCategoryCubit, VocabularyCategoryState>(
                  builder: (context, state) {
                    return FilledButton(
                      onPressed: () async {
                        final cubitCategory = context.read<VocabularyCategoryCubit>();
                        String finalName = selectedCategoryName;
                        int? finalId = selectedCategoryId;

                        if (categoryController.text.trim().isNotEmpty) {
                          finalName = categoryController.text.trim();
                          await cubitCategory.createCategory(finalName);
                          finalId = null;
                        }

                        cubit.saveVocabulary(
                          word: word,
                          translation: translation,
                          sourceLanguage: sourceLanguage,
                          targetLanguage: targetLanguage,
                          category: finalName,
                          categoryId: finalId,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      },
                      child: const Text('Lưu'),
                    );
                  }
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
