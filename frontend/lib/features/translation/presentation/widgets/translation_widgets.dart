import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/injection_container.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';
import 'package:frontend/features/translation/presentation/widgets/shimmer_loading_widget.dart';

// ---------------------------------------------------------------------------
// QuickTranslateWidget — compact version for home screens.
// Wraps its own BlocProvider so it's self-contained.
// ---------------------------------------------------------------------------

class QuickTranslateWidget extends StatelessWidget {
  final bool isAuthenticated;

  const QuickTranslateWidget({super.key, this.isAuthenticated = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TranslationCubit>(),
      child: _QuickTranslateView(isAuthenticated: isAuthenticated),
    );
  }
}

class _QuickTranslateView extends StatefulWidget {
  final bool isAuthenticated;

  const _QuickTranslateView({required this.isAuthenticated});

  @override
  State<_QuickTranslateView> createState() => _QuickTranslateViewState();
}

class _QuickTranslateViewState extends State<_QuickTranslateView> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _srcCode = 'auto';
  String _tgtCode = 'vi';

  static const Map<String, String> _langNames = {
    'auto': 'Tự động',
    'en': 'Tiếng Anh',
    'vi': 'Tiếng Việt',
    'fr': 'Tiếng Pháp',
    'ja': 'Tiếng Nhật',
    'ko': 'Tiếng Hàn',
    'zh': 'Tiếng Trung',
    'de': 'Tiếng Đức',
    'es': 'Tiếng Tây Ban Nha',
  };

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      context.read<TranslationCubit>().reset();
      return;
    }
    // Client-side validation: max 5,000 characters (§7.2).
    if (trimmed.length > 5000) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      context.read<TranslationCubit>().translateText(
        text: trimmed,
        sourceLanguage: _srcCode,
        targetLanguage: _tgtCode,
      );
    });
  }

  void _swapLanguages() {
    if (_srcCode == 'auto') return;
    final state = context.read<TranslationCubit>().state;
    String? swappedText;
    if (state is TranslationSuccess) {
      swappedText = state.translation.translatedText;
    }
    setState(() {
      final tmp = _srcCode;
      _srcCode = _tgtCode;
      _tgtCode = tmp;
    });
    if (swappedText != null && swappedText.isNotEmpty) {
      _controller.text = swappedText;
      _onTextChanged(swappedText);
    } else {
      context.read<TranslationCubit>().reset();
    }
  }

  void _clear() {
    _controller.clear();
    context.read<TranslationCubit>().reset();
  }

  Future<void> _pickLanguage({required bool isSource}) async {
    // UC02: Language switching is available to Guest and User (no auth needed).

    final langs = isSource ? _langNames : Map.of(_langNames)
      ..remove('auto');
    final current = isSource ? _srcCode : _tgtCode;

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _QuickLanguagePickerSheet(langs: langs, selected: current),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isSource) {
        _srcCode = picked;
      } else {
        _tgtCode = picked;
      }
    });
    if (_controller.text.trim().isNotEmpty) {
      _onTextChanged(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasText = _controller.text.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/translate'),
      behavior: HitTestBehavior.translucent,
      child: AbsorbPointer(
        absorbing: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language selector
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickLanguage(isSource: true),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _langNames[_srcCode] ?? _srcCode,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: cs.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    color: _srcCode != 'auto'
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.3),
                    onPressed: _srcCode != 'auto' ? _swapLanguages : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickLanguage(isSource: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _langNames[_tgtCode] ?? _tgtCode,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: cs.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              // Input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Nhập văn bản cần dịch...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onTextChanged,
                    ),
                  ),
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      color: cs.onSurfaceVariant,
                      onPressed: _clear,
                    ),
                ],
              ),
              // Result
              BlocBuilder<TranslationCubit, TranslationState>(
                builder: (ctx, state) {
                  if (state is TranslationInitial) {
                    return const SizedBox.shrink();
                  }
                  if (state is TranslationInProgress) {
                    return const ShimmerTranslationLoadingCompact();
                  }
                  if (state is TranslationSuccess) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
                        Text(
                          state.translation.translatedText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: state.translation.translatedText,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép bản dịch'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Sao chép'),
                          ),
                        ),
                      ],
                    );
                  }
                  if (state is TranslationFailure) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              state.message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Open full page hint
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => context.push('/translate'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mở màn hình dịch',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language picker bottom sheet specifically for QuickTranslate
// ---------------------------------------------------------------------------

class _QuickLanguagePickerSheet extends StatelessWidget {
  final Map<String, String> langs;
  final String selected;

  const _QuickLanguagePickerSheet({
    required this.langs,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = langs.entries.toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn ngôn ngữ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (ctx, i) {
                final code = entries[i].key;
                final name = entries[i].value;
                final isSelected = code == selected;

                // Cờ tượng trưng
                String flag = '🌐';
                if (code == 'en') flag = '🇺🇸';
                if (code == 'vi') flag = '🇻🇳';
                if (code == 'ja') flag = '🇯🇵';
                if (code == 'ko') flag = '🇰🇷';
                if (code == 'zh') flag = '🇨🇳';
                if (code == 'fr') flag = '🇫🇷';
                if (code == 'es') flag = '🇪🇸';
                if (code == 'de') flag = '🇩🇪';
                if (code == 'auto') flag = '🔍';

                return ListTile(
                  leading: Text(flag, style: const TextStyle(fontSize: 24)),
                  title: Text(name),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  selected: isSelected,
                  selectedTileColor: cs.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(code),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
