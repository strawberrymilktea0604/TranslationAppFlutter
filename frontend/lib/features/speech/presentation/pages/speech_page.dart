import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/speech/presentation/bloc/speech_cubit.dart';

// ---------------------------------------------------------------------------
// Entry point — shows the voice translation bottom sheet.
// Callers must ensure SpeechCubit is in the widget tree.
// ---------------------------------------------------------------------------

Future<void> showVoiceTranslationSheet(
  BuildContext context, {
  required String srcLang,
  required String tgtLang,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => BlocProvider.value(
      value: context.read<SpeechCubit>(),
      child: _VoiceSheet(srcLang: srcLang, tgtLang: tgtLang),
    ),
  );
}

// ---------------------------------------------------------------------------
// Language label helper
// ---------------------------------------------------------------------------

String _langName(String code) {
  const map = {
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
  return map[code] ?? code.toUpperCase();
}

// ---------------------------------------------------------------------------
// Bottom sheet widget
// ---------------------------------------------------------------------------

class _VoiceSheet extends StatefulWidget {
  final String srcLang;
  final String tgtLang;

  const _VoiceSheet({required this.srcLang, required this.tgtLang});

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet>
    with TickerProviderStateMixin {
  // Idle pulse animation (rings expand when NOT recording)
  late final AnimationController _pulseCtrl;

  // Wave bar animation (bars animate when recording)
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Auto-start listening when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpeechCubit>().startListening(
            srcLang: widget.srcLang,
            tgtLang: widget.tgtLang,
          );
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
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

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocConsumer<SpeechCubit, SpeechState>(
      listener: (context, state) {
        // Close on success after a short delay (user can read result)
        // Actually we keep it open so user can TTS / copy.
        // Close automatically only on cancel.
      },
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Language bar
              _buildLangBar(cs, theme, state),
              const SizedBox(height: 32),

              // Central mic + visualiser area
              SizedBox(
                height: 200,
                child: _buildVisualiser(cs, state),
              ),
              const SizedBox(height: 24),

              // Status label + transcript
              _buildStatusArea(cs, theme, state),
              const SizedBox(height: 28),

              // Control buttons
              _buildControls(cs, theme, state),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // Language bar
  // =========================================================================

  Widget _buildLangBar(ColorScheme cs, ThemeData theme, SpeechState state) {
    final String src;
    final String tgt;

    if (state is SpeechListening) {
      src = state.srcLang;
      tgt = state.tgtLang;
    } else if (state is SpeechTranslating) {
      src = state.srcLang;
      tgt = state.tgtLang;
    } else if (state is SpeechSuccess) {
      src = state.srcLang;
      tgt = state.tgtLang;
    } else {
      src = widget.srcLang;
      tgt = widget.tgtLang;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LangChip(label: _langName(src), cs: cs),
        const SizedBox(width: 12),
        Icon(Icons.arrow_forward_rounded, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        _LangChip(label: _langName(tgt), cs: cs, isPrimary: true),
      ],
    );
  }

  // =========================================================================
  // Visualiser (center)
  // =========================================================================

  Widget _buildVisualiser(ColorScheme cs, SpeechState state) {
    final isListening = state is SpeechListening;
    final isTranslating = state is SpeechTranslating;
    final amplitude = isListening ? (state as SpeechListening).amplitude : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing rings (always visible, extra glow when listening)
        if (!isTranslating)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              size: const Size(200, 200),
              painter: _PulseRingPainter(
                progress: _pulseCtrl.value,
                color: isListening ? AppTheme.primaryColor : cs.outlineVariant,
                amplitude: amplitude,
                isListening: isListening,
              ),
            ),
          ),

        // Wave bars (only when recording)
        if (isListening)
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, __) => CustomPaint(
              size: const Size(200, 200),
              painter: _WaveBarPainter(
                animValue: _waveCtrl.value,
                amplitude: amplitude,
                color: AppTheme.primaryColor,
              ),
            ),
          ),

        // Translating spinner
        if (isTranslating)
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primaryColor,
            ),
          ),

        // Mic button (center)
        _MicButton(
          isListening: isListening,
          isTranslating: isTranslating,
          amplitude: amplitude,
          onTap: isTranslating
              ? null
              : isListening
                  ? () => context.read<SpeechCubit>().stopListening()
                  : () => context.read<SpeechCubit>().startListening(
                        srcLang: widget.srcLang,
                        tgtLang: widget.tgtLang,
                      ),
        ),
      ],
    );
  }

  // =========================================================================
  // Status area
  // =========================================================================

  Widget _buildStatusArea(
      ColorScheme cs, ThemeData theme, SpeechState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (state) {
          SpeechInitial() => Text(
              'Bấm mic để bắt đầu',
              key: const ValueKey('idle'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          SpeechListening(partialText: final text) => Column(
              key: const ValueKey('listening'),
              children: [
                Text(
                  'Speak something...',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          SpeechTranslating(recognisedText: final text) => Column(
              key: const ValueKey('translating'),
              children: [
                Text(
                  text,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Đang dịch...',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          SpeechSuccess(
            recognisedText: final src,
            translatedText: final tgt,
            tgtLang: final tgtLang,
            srcLang: final srcLang,
          ) =>
            _ResultCard(
              key: const ValueKey('success'),
              sourceText: src,
              translatedText: tgt,
              srcLang: srcLang,
              tgtLang: tgtLang,
              onCopySource: () =>
                  _copyText(src, 'Đã sao chép văn bản nguồn'),
              onCopyTranslation: () =>
                  _copyText(tgt, 'Đã sao chép bản dịch'),
              theme: theme,
              cs: cs,
            ),
          SpeechFailure(message: final msg) => Column(
              key: const ValueKey('failure'),
              children: [
                Icon(Icons.error_outline_rounded,
                    color: cs.error, size: 32),
                const SizedBox(height: 8),
                Text(
                  msg,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
        },
      ),
    );
  }

  // =========================================================================
  // Controls
  // =========================================================================

  Widget _buildControls(
      ColorScheme cs, ThemeData theme, SpeechState state) {
    final isListening = state is SpeechListening;
    final isSuccess = state is SpeechSuccess;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cancel / close
        _ControlBtn(
          icon: Icons.close_rounded,
          label: 'Đóng',
          color: cs.onSurfaceVariant,
          bgColor: cs.surfaceContainerHighest,
          onTap: () {
            context.read<SpeechCubit>().cancel();
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(width: 32),

        // Retry (only after success or failure)
        if (isSuccess || state is SpeechFailure)
          _ControlBtn(
            icon: Icons.refresh_rounded,
            label: 'Thử lại',
            color: Colors.white,
            bgColor: AppTheme.primaryColor,
            onTap: () => context.read<SpeechCubit>().startListening(
                  srcLang: widget.srcLang,
                  tgtLang: widget.tgtLang,
                ),
          ),

        // Stop (while listening)
        if (isListening)
          _ControlBtn(
            icon: Icons.stop_rounded,
            label: 'Dừng',
            color: Colors.white,
            bgColor: AppTheme.primaryColor,
            onTap: () => context.read<SpeechCubit>().stopListening(),
          ),
      ],
    );
  }
}

// ===========================================================================
// Mic button
// ===========================================================================

class _MicButton extends StatelessWidget {
  final bool isListening;
  final bool isTranslating;
  final double amplitude;
  final VoidCallback? onTap;

  const _MicButton({
    required this.isListening,
    required this.isTranslating,
    required this.amplitude,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Scale slightly with amplitude
    final scale = isListening ? (1.0 + amplitude * 0.12) : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isListening
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      const Color(0xFFE0E0E0),
                      const Color(0xFFBDBDBD),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: [
              BoxShadow(
                color: isListening
                    ? AppTheme.primaryColor.withValues(alpha: 0.4 + amplitude * 0.3)
                    : Colors.black.withValues(alpha: 0.15),
                blurRadius: isListening ? 20 + amplitude * 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isTranslating ? Icons.hourglass_top_rounded : Icons.mic_rounded,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Custom painters
// ===========================================================================

/// Concentric pulsing rings behind the mic button.
class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double amplitude;
  final bool isListening;

  _PulseRingPainter({
    required this.progress,
    required this.color,
    required this.amplitude,
    required this.isListening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 44.0;
    const maxRadius = 90.0;

    for (int i = 0; i < 3; i++) {
      final delay = i / 3;
      final t = ((progress - delay) % 1.0 + 1.0) % 1.0;
      final radius = baseRadius + (maxRadius - baseRadius) * t;

      // Extra rings when listening: amplitude boosts opacity & size
      final extraBoost = isListening ? amplitude * 0.3 : 0.0;
      final opacity = (1.0 - t) * (0.35 + extraBoost);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isListening ? 2.5 : 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.progress != progress ||
      old.amplitude != amplitude ||
      old.isListening != isListening;
}

/// Vertical bars that animate with real amplitude (audio visualiser).
class _WaveBarPainter extends CustomPainter {
  final double animValue; // 0.0 → 1.0, repeats
  final double amplitude; // 0.0 → 1.0 from STT
  final Color color;

  static const _barCount = 28;

  _WaveBarPainter({
    required this.animValue,
    required this.amplitude,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const barWidth = 4.0;
    const barSpacing = 5.0;
    final totalWidth = _barCount * (barWidth + barSpacing) - barSpacing;
    final startX = centerX - totalWidth / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final rng = math.Random(42); // fixed seed for stable shape

    for (int i = 0; i < _barCount; i++) {
      final x = startX + i * (barWidth + barSpacing) + barWidth / 2;

      // Each bar has a unique phase so they move independently
      final phase = rng.nextDouble() * math.pi * 2;
      final barAnim = (math.sin(animValue * math.pi * 2 + phase) + 1) / 2;

      // Base height grows with amplitude; minimum height guarantees activity
      final minH = 6.0;
      final maxH = size.height * 0.38;
      final barH = minH + (maxH - minH) * (amplitude * 0.75 + barAnim * 0.25);

      final top = centerY - barH / 2;
      final bottom = centerY + barH / 2;

      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveBarPainter old) =>
      old.animValue != animValue || old.amplitude != amplitude;
}

// ===========================================================================
// Helper widgets
// ===========================================================================

class _LangChip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final bool isPrimary;

  const _LangChip({
    required this.label,
    required this.cs,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isPrimary ? AppTheme.primaryColor : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color == Colors.white ? bgColor : color),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Result card (success state)
// ===========================================================================

class _ResultCard extends StatelessWidget {
  final String sourceText;
  final String translatedText;
  final String srcLang;
  final String tgtLang;
  final VoidCallback onCopySource;
  final VoidCallback onCopyTranslation;
  final ThemeData theme;
  final ColorScheme cs;

  const _ResultCard({
    super.key,
    required this.sourceText,
    required this.translatedText,
    required this.srcLang,
    required this.tgtLang,
    required this.onCopySource,
    required this.onCopyTranslation,
    required this.theme,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Source text
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sourceText,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TtsIconButton(
                    text: sourceText,
                    languageCode: srcLang == 'auto' ? 'en' : srcLang,
                    tooltip: 'Phát âm gốc',
                    iconSize: 18,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    tooltip: 'Sao chép',
                    color: cs.onSurfaceVariant,
                    onPressed: onCopySource,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Arrow
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: cs.primary, size: 22),
          ),
        ),

        // Translation text
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translatedText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TtsIconButton(
                    text: translatedText,
                    languageCode: tgtLang,
                    tooltip: 'Phát âm bản dịch',
                    iconSize: 18,
                    activeColor: AppTheme.primaryColor,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    tooltip: 'Sao chép',
                    color: AppTheme.primaryColor,
                    onPressed: onCopyTranslation,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
