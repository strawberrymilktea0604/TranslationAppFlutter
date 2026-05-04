import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/injection_container.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/features/ocr/presentation/bloc/ocr_cubit.dart';
import 'package:frontend/features/ocr/presentation/pages/ocr_page.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';
import 'package:frontend/features/translation/presentation/widgets/shimmer_loading_widget.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ---------------------------------------------------------------------------
// Language model
// ---------------------------------------------------------------------------

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
// Entry point — wraps page in BlocProvider
// ---------------------------------------------------------------------------

class TranslationPage extends StatelessWidget {
  const TranslationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<TranslationCubit>()),
        BlocProvider(create: (_) => sl<OcrCubit>()),
      ],
      child: const _TranslationView(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main view
// ---------------------------------------------------------------------------

class _TranslationView extends StatefulWidget {
  const _TranslationView();

  @override
  State<_TranslationView> createState() => _TranslationViewState();
}

class _TranslationViewState extends State<_TranslationView>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _srcCode = 'auto';
  String _tgtCode = 'vi';
  int _currentIndex = 0;
  late AnimationController _swapAnim;

  @override
  void initState() {
    super.initState();
    _swapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _swapAnim.dispose();
    super.dispose();
  }

  // ---- constants ----

  /// Maximum character length per translation request (§7.2).
  static const int _kMaxTextLength = 5000;

  // ---- helpers ----

  TranslationCubit get _cubit => context.read<TranslationCubit>();

  // Removed _isAuthenticated getter since we will use BlocBuilder directly in build

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _cubit.reset();
      return;
    }
    // Client-side validation: max 5,000 characters per request (§7.2).
    if (trimmed.length > _kMaxTextLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Văn bản vượt quá $_kMaxTextLength ký tự '
            '(hiện tại: ${trimmed.length})',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _cubit.translateText(
        text: trimmed,
        sourceLanguage: _srcCode,
        targetLanguage: _tgtCode,
      );
    });
  }

  void _swapLanguages() {
    if (_srcCode == 'auto') return;
    _swapAnim.forward(from: 0);
    final state = _cubit.state;
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
      _cubit.reset();
    }
  }

  void _clear() {
    _controller.clear();
    _cubit.reset();
    setState(() {}); // refresh hasText
  }

  void _copyText(String text, String label) {
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

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yêu cầu đăng nhập'),
        content: const Text('Vui lòng đăng nhập để sử dụng tính năng này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/login');
            },
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage({required bool isSource}) async {
    final langs = isSource
        ? _kLangs
        : _kLangs.where((l) => l.code != 'auto').toList();
    final current = isSource ? _srcCode : _tgtCode;

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LanguagePickerSheet(langs: langs, selected: current),
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

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isAuth = authState is AuthAuthenticated;
        
        return Scaffold(
          drawer: const Drawer(),
        appBar: AppBar(
          title: const Text('Dịch thuật'),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0, left: 4.0),
              child: InkWell(
                onTap: () {
                  context.push('/profile');
                },
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: isAuth ? cs.primaryContainer : cs.surfaceContainerHighest,
                  backgroundImage: (isAuth && authState.user.avatarUrl != null && authState.user.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(authState.user.avatarUrl!)
                      : null,
                  child: (isAuth && authState.user.avatarUrl != null && authState.user.avatarUrl!.isNotEmpty)
                      ? null
                      : Icon(
                          isAuth ? Icons.person_rounded : Icons.person_outline_rounded,
                          size: 22,
                          color: isAuth ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                        ),
                ),
              ),
            ),
          ],
        ),
        // Use LayoutBuilder to prevent bottom overflow on small screens.
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildCurrentTab(context, cs, theme, isAuth),
          ),
        ),
        bottomNavigationBar: isAuth
            ? NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.translate_rounded),
                    label: 'Dịch',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.lens_blur_rounded),
                    label: 'Lens',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bookmark_rounded),
                    label: 'Từ vựng',
                  ),
                ],
              )
            : null,
        );
      },
    );
  }

  Widget _buildCurrentTab(BuildContext context, ColorScheme cs, ThemeData theme, bool isAuth) {
    if (_currentIndex == 1) {
      // Lens tab — full OCR page (state managed by OcrCubit provided above)
      return const OcrPage(key: ValueKey('lens'));
    } else if (_currentIndex == 2) {
      return _buildVocabPlaceholder(cs, key: const ValueKey('vocab'));
    }
    return _buildTranslationTab(context, cs, theme, isAuth, key: const ValueKey('translate'));
  }

  Widget _buildVocabPlaceholder(ColorScheme cs, {Key? key}) {
    return Center(
      key: key,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_rounded,
              size: 64, color: cs.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Từ vựng',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Tính năng đang phát triển 🚀',
            style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationTab(BuildContext context, ColorScheme cs, ThemeData theme, bool isAuth, {Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 24,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Guest CTA banner
                  if (!isAuth) _buildGuestBanner(cs, theme),
                  _buildLangBar(cs),
                  const SizedBox(height: 10),
                  Expanded(child: _buildSourceCard(theme, isAuth)),
                  const SizedBox(height: 10),
                  Expanded(child: _buildResultCard(theme, isAuth)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- Guest CTA banner ----

  Widget _buildGuestBanner(ColorScheme cs, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.08),
            cs.tertiary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đăng nhập để mở khóa giọng nói, hình ảnh, lưu từ vựng.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => context.push('/login'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Đăng nhập',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Language bar ----

  Widget _buildLangBar(ColorScheme cs) {
    final src = _findLang(_srcCode);
    final tgt = _findLang(_tgtCode);
    final canSwap = _srcCode != 'auto';

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              onTap: () => _pickLanguage(isSource: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
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
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 18, color: cs.primary),
                  ],
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: Tween(begin: 0.0, end: 0.5).animate(
              CurvedAnimation(parent: _swapAnim, curve: Curves.easeInOut),
            ),
            child: IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, size: 22),
              color: canSwap ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
              tooltip: 'Đổi ngôn ngữ',
              onPressed: canSwap ? _swapLanguages : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14),
              ),
              onTap: () => _pickLanguage(isSource: false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
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
                    const SizedBox(width: 2),
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

  // ---- Source card ----

  Widget _buildSourceCard(ThemeData theme, bool isAuth) {
    final cs = theme.colorScheme;
    final hasText = _controller.text.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + clear button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Text(
                  'Nguồn · ${_findLang(_srcCode).name}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (hasText)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Xóa',
                    color: cs.onSurfaceVariant,
                    onPressed: _clear,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // TextField
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Nhập văn bản cần dịch...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) {
                  setState(() {}); // refresh hasText
                  _onTextChanged(v);
                },
              ),
            ),
          ),
          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isAuth ? Icons.mic_outlined : Icons.lock_outline_rounded, size: 22),
                  tooltip: isAuth ? 'Dịch bằng giọng nói' : 'Đăng nhập để sử dụng giọng nói',
                  color: isAuth ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.3),
                  onPressed: isAuth ? () => _showComingSoon('Dịch giọng nói') : _showLoginDialog,
                ),
                const Spacer(),
                TtsIconButton(
                  text: _controller.text,
                  languageCode: _srcCode == 'auto' ? 'en' : _srcCode,
                  tooltip: 'Phát âm văn bản nguồn',
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  tooltip: 'Sao chép',
                  color: hasText
                      ? AppTheme.primaryColor
                      : cs.onSurface.withValues(alpha: 0.3),
                  onPressed: hasText
                      ? () => _copyText(
                          _controller.text,
                          'Đã sao chép văn bản nguồn',
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Result card ----

  Widget _buildResultCard(ThemeData theme, bool isAuth) {
    final cs = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Dịch · ${_findLang(_tgtCode).name}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: BlocBuilder<TranslationCubit, TranslationState>(
                builder: (context, state) {
                  return switch (state) {
                    TranslationInitial() => _ResultHint(cs: cs),
                    TranslationInProgress() => const _ResultLoading(),
                    TranslationSuccess(translation: final t) => _ResultText(
                      text: t.translatedText,
                      theme: theme,
                    ),
                    TranslationFailure(message: final msg) => _ResultError(
                      message: msg,
                      theme: theme,
                    ),
                  };
                },
              ),
            ),
          ),
          // Action bar
          BlocBuilder<TranslationCubit, TranslationState>(
            builder: (context, state) {
              final resultText = state is TranslationSuccess
                  ? state.translation.translatedText
                  : null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                child: Row(
                  children: [
                    // UC07 — Lưu từ vựng: requires Auth.
                    if (isAuth)
                      IconButton(
                        icon: const Icon(
                          Icons.bookmark_border_rounded,
                          size: 20,
                        ),
                        tooltip: 'Lưu từ vựng',
                        color: cs.onSurfaceVariant,
                        onPressed: () => _showComingSoon('Lưu từ vựng'),
                      )
                    else
                      Tooltip(
                        message: 'Đăng nhập để lưu từ vựng',
                        child: IconButton(
                          icon: const Icon(Icons.lock_outline_rounded, size: 18),
                          color: cs.onSurface.withValues(alpha: 0.3),
                          onPressed: _showLoginDialog,
                        ),
                      ),
                    const Spacer(),
                    // UC03 — TTS: available to Guest and User.
                    if (resultText != null)
                      TtsIconButton(
                        text: resultText,
                        languageCode: _tgtCode,
                        tooltip: 'Phát âm bản dịch',
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      tooltip: 'Sao chép',
                      color: resultText != null
                          ? AppTheme.primaryColor
                          : cs.onSurface.withValues(alpha: 0.3),
                      onPressed: resultText != null
                          ? () => _copyText(resultText, 'Đã sao chép bản dịch')
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result sub-states
// ---------------------------------------------------------------------------

class _ResultHint extends StatelessWidget {
  final ColorScheme cs;
  const _ResultHint({required this.cs});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.translate_rounded,
          size: 36,
          color: cs.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 10),
        Text(
          'Bản dịch sẽ xuất hiện ở đây',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45)),
        ),
      ],
    ),
  );
}

class _ResultLoading extends StatelessWidget {
  const _ResultLoading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: ShimmerTranslationLoading(lineCount: 3),
    );
  }
}

class _ResultText extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _ResultText({required this.text, required this.theme});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: AppTheme.primaryColor,
        height: 1.5,
      ),
    ),
  );
}

class _ResultError extends StatelessWidget {
  final String message;
  final ThemeData theme;
  const _ResultError({required this.message, required this.theme});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 32,
          color: theme.colorScheme.error.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Language picker bottom sheet
// ---------------------------------------------------------------------------

class _LanguagePickerSheet extends StatelessWidget {
  final List<_Lang> langs;
  final String selected;

  const _LanguagePickerSheet({required this.langs, required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              itemCount: langs.length,
              itemBuilder: (ctx, i) {
                final l = langs[i];
                final isSelected = l.code == selected;
                return ListTile(
                  leading: Text(l.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(l.name),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  selected: isSelected,
                  selectedTileColor: cs.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(l.code),
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
