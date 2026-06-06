import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/ocr/presentation/bloc/ocr_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/widgets/save_vocabulary_dialog.dart';

// Language model (shared with TranslationPage)
class _Lang {
  final String code;
  final String name;
  final String flag;
  const _Lang({required this.code, required this.name, required this.flag});
}

const _kLangs = [
  _Lang(code: 'auto', name: 'Tự động', flag: '🔍'),
  _Lang(code: 'en', name: 'Tiếng Anh', flag: '🇺🇸'),
  _Lang(code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳'),
  _Lang(code: 'fr', name: 'Tiếng Pháp', flag: '🇫🇷'),
  _Lang(code: 'ja', name: 'Tiếng Nhật', flag: '🇯🇵'),
  _Lang(code: 'ko', name: 'Tiếng Hàn', flag: '🇰🇷'),
  _Lang(code: 'zh', name: 'Tiếng Trung', flag: '🇨🇳'),
  _Lang(code: 'de', name: 'Tiếng Đức', flag: '🇩🇪'),
  _Lang(code: 'es', name: 'Tiếng Tây Ban Nha', flag: '🇪🇸'),
];

_Lang _findLang(String code) =>
    _kLangs.firstWhere((l) => l.code == code, orElse: () => _kLangs[1]);

// ---------------------------------------------------------------------------
// OcrPage — stateful to own language selectors and text editing controller
// ---------------------------------------------------------------------------

class OcrPage extends StatefulWidget {
  const OcrPage({super.key});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  String _srcLang = 'en';
  String _tgtLang = 'vi';
  final _editController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  OcrCubit get _cubit => context.read<OcrCubit>();

  // ---- Language picker ---------------------------------------------------

  Future<void> _pickLang({required bool isSource}) async {
    final langs = isSource
        ? _kLangs
        : _kLangs.where((l) => l.code != 'auto').toList();
    final current = isSource ? _srcLang : _tgtLang;

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LangPickerSheet(langs: langs, selected: current),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isSource) {
        _srcLang = picked;
      } else {
        _tgtLang = picked;
      }
    });
  }

  // ---- Image source -------------------------------------------------------

  void _pickImage(ImageSource source) {
    _isEditing = false;
    _cubit.pickAndProcess(
      source: source,
      srcLang: _srcLang,
      tgtLang: _tgtLang,
      themeData: Theme.of(context),
    );
  }

  // ---- Copy helper --------------------------------------------------------

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — tính năng sắp ra mắt 🚀'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocConsumer<OcrCubit, OcrState>(
      listener: (context, state) {
        if (state is OcrSuccess) {
          // Sync editor with new extracted text (only if not currently editing)
          if (!_isEditing) {
            _editController.text = state.extractedText;
          }
        }
        if (state is OcrRetranslating) {
          _editController.text = state.editedText;
        }
        if (state is OcrFailure) {
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
      builder: (context, state) {
        return Column(
          children: [
            // ---- Language bar ----
            _buildLangBar(cs),

            // ---- Main content area ----
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (state) {
                  OcrInitial() => _buildInitial(cs, theme),
                  OcrImagePicked() => _buildLoading(
                      cs, theme, 0.0, 'Đang mở khung cắt ảnh...'),
                  OcrUploading(
                    progress: final p,
                    message: final msg,
                  ) =>
                    _buildLoading(cs, theme, p, msg),
                  OcrSuccess() => _buildSuccess(cs, theme, state),
                  OcrRetranslating() =>
                    _buildRetranslating(cs, theme, state),
                  OcrFailure(message: final msg) =>
                    _buildFailure(cs, theme, msg),
                },
              ),
            ),

            // ---- Bottom action bar (only in initial state) ----
            if (state is OcrInitial)
              _buildBottomBar(cs)
            else if (state is OcrFailure)
              _buildBottomBar(cs),
          ],
        );
      },
    );
  }

  // =========================================================================
  // Language bar
  // =========================================================================

  Widget _buildLangBar(ColorScheme cs) {
    final src = _findLang(_srcLang);
    final tgt = _findLang(_tgtLang);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              onTap: () => _pickLang(isSource: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(src.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        src.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 18, color: cs.primary),
                  ],
                ),
              ),
            ),
          ),
          Icon(Icons.camera_alt_outlined, size: 20, color: cs.onSurfaceVariant),
          Expanded(
            child: InkWell(
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(14)),
              onTap: () => _pickLang(isSource: false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tgt.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tgt.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 18, color: cs.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // State: Initial
  // =========================================================================

  Widget _buildInitial(ColorScheme cs, ThemeData theme) {
    return Center(
      key: const ValueKey('initial'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.document_scanner_rounded,
              size: 52,
              color: cs.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aim at text to translate',
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn ảnh từ thư viện hoặc chụp ảnh mới',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // State: Loading / Uploading
  // =========================================================================

  Widget _buildLoading(
      ColorScheme cs, ThemeData theme, double progress, String message) {
    final pct = (progress * 100).toInt().clamp(0, 100);
    final isProcessing = progress >= 1.0;

    return Center(
      key: const ValueKey('loading'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: isProcessing
                  ? Icon(Icons.document_scanner_rounded,
                      key: const ValueKey('scan'),
                      size: 56,
                      color: cs.primary)
                  : Icon(Icons.cloud_upload_outlined,
                      key: const ValueKey('upload'),
                      size: 56,
                      color: cs.primary),
            ),
            const SizedBox(height: 28),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: isProcessing ? null : progress, // null = indeterminate
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 14),

            // Label
            Text(
              isProcessing ? message : '$message ($pct%)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // State: Retranslating
  // =========================================================================

  Widget _buildRetranslating(
      ColorScheme cs, ThemeData theme, OcrRetranslating state) {
    return _buildLoading(cs, theme, 1.0, 'Đang dịch lại...');
  }

  // =========================================================================
  // State: Failure
  // =========================================================================

  Widget _buildFailure(ColorScheme cs, ThemeData theme, String message) {
    return Center(
      key: const ValueKey('failure'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Đã xảy ra lỗi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _cubit.reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // State: Success
  // =========================================================================

  Widget _buildSuccess(ColorScheme cs, ThemeData theme, OcrSuccess state) {
    return SingleChildScrollView(
      key: const ValueKey('success'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Image preview ----
          _buildImagePreview(cs, state.imageBytes),
          const SizedBox(height: 12),

          // ---- OCR text card (editable) ----
          _buildOcrCard(cs, theme, state),
          const SizedBox(height: 10),

          // ---- Translation result card ----
          _buildTranslationCard(cs, theme, state),
          const SizedBox(height: 8),

          // ---- Reset button ----
          TextButton.icon(
            onPressed: () {
              _isEditing = false;
              _cubit.reset();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Chọn ảnh khác'),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Image preview ----

  Widget _buildImagePreview(ColorScheme cs, Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }

  // ---- OCR card ----

  Widget _buildOcrCard(ColorScheme cs, ThemeData theme, OcrSuccess state) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                Icon(Icons.document_scanner_outlined,
                    size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Văn bản gốc · ${_findLang(state.sourceLang).name}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (state.confidence != null) ...[
                  const Spacer(),
                  _ConfidenceChip(confidence: state.confidence!),
                ],
              ],
            ),
          ),

          // Editable text field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _editController,
              maxLines: null,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Chỉnh sửa văn bản OCR nếu cần...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.4),
                  ),
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.all(10),
              ),
              onChanged: (_) {
                _isEditing = true;
                setState(() {});
              },
            ),
          ),

          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                // TTS for source
                TtsIconButton(
                  text: _editController.text,
                  languageCode:
                      state.sourceLang == 'auto' ? 'en' : state.sourceLang,
                  tooltip: 'Phát âm văn bản gốc',
                ),
                const Spacer(),
                // Copy source
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  tooltip: 'Sao chép',
                  color: AppTheme.primaryColor,
                  onPressed: () =>
                      _copy(_editController.text, 'Đã sao chép văn bản gốc'),
                ),
                // Re-translate button
                FilledButton.icon(
                  onPressed: _editController.text.trim().isEmpty
                      ? null
                      : () {
                          _isEditing = false;
                          _cubit.retranslate(
                            editedText: _editController.text,
                            imageBytes: state.imageBytes,
                            srcLang: state.sourceLang,
                            tgtLang: state.targetLang,
                          );
                        },
                  icon: const Icon(Icons.translate_rounded, size: 16),
                  label: const Text('Dịch lại'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Translation card ----

  Widget _buildTranslationCard(
      ColorScheme cs, ThemeData theme, OcrSuccess state) {
    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Icon(Icons.translate_rounded,
                    size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Bản dịch · ${_findLang(state.targetLang).name}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Translation text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SelectableText(
              state.translatedText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.primaryColor,
                height: 1.5,
              ),
            ),
          ),

          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                // TTS for translation
                TtsIconButton(
                  text: state.translatedText,
                  languageCode: state.targetLang,
                  tooltip: 'Phát âm bản dịch',
                ),
                const Spacer(),
                // Copy translation
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  tooltip: 'Sao chép bản dịch',
                  color: AppTheme.primaryColor,
                  onPressed: () =>
                      _copy(state.translatedText, 'Đã sao chép bản dịch'),
                ),
                // Save flashcard
                IconButton(
                  icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                  tooltip: 'Lưu Flashcard',
                  color: cs.onSurfaceVariant,
                  onPressed: () {
                    showSaveVocabularyDialog(
                      context: context,
                      cubit: context.read<VocabularyCubit>(),
                      word: state.extractedText,
                      translation: state.translatedText,
                      sourceLanguage: state.sourceLang,
                      targetLanguage: state.targetLang,
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Bottom bar (initial & failure states)
  // =========================================================================

  Widget _buildBottomBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button (left)
          _BottomActionButton(
            icon: Icons.photo_library_outlined,
            label: 'Thư viện',
            onTap: () => _pickImage(ImageSource.gallery),
            cs: cs,
          ),

          // Camera button (center, larger)
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, cs.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 30, color: Colors.white),
            ),
          ),

          // Gallery button (right, same as left for now)
          _BottomActionButton(
            icon: Icons.image_search_rounded,
            label: 'Tìm kiếm',
            onTap: () => _showComingSoon('Tìm kiếm bằng ảnh'),
            cs: cs,
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Helper widgets
// =========================================================================

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  final double confidence;
  const _ConfidenceChip({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final isHigh = confidence >= 80;
    final color =
        isHigh ? AppTheme.successColor : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'OCR ${confidence.toInt()}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// =========================================================================
// Language picker bottom sheet
// =========================================================================

class _LangPickerSheet extends StatelessWidget {
  final List<_Lang> langs;
  final String selected;

  const _LangPickerSheet({required this.langs, required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Chọn ngôn ngữ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: langs.length,
              itemBuilder: (_, i) {
                final l = langs[i];
                final isSelected = l.code == selected;
                return ListTile(
                  leading: Text(l.flag,
                      style: const TextStyle(fontSize: 22)),
                  title: Text(l.name),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  selected: isSelected,
                  onTap: () => Navigator.pop(context, l.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
