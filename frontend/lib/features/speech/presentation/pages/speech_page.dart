import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/core/audio_recorder/bloc/recording_cubit.dart';
import 'package:frontend/core/audio_recorder/bloc/recording_state.dart';
import 'package:frontend/features/speech/presentation/bloc/speech_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_state.dart';
import 'package:frontend/features/vocabulary/presentation/widgets/save_vocabulary_dialog.dart';
import 'package:frontend/injection_container.dart';

// ---------------------------------------------------------------------------
// Entry point
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
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<SpeechCubit>()),
        BlocProvider(create: (_) => sl<RecordingCubit>()),
        BlocProvider(create: (_) => sl<VocabularyCubit>()),
      ],
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
  late final SpeechCubit _speechCubit;
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _speechCubit = context.read<SpeechCubit>();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _speechCubit.reset();
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

    return BlocListener<VocabularyCubit, VocabularyState>(
      listener: (context, state) {
        if (state is VocabularySaveSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã lưu "${state.savedEntry.word}"'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        if (state is VocabularyFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi lưu từ vựng: ${state.message}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: cs.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: BlocListener<RecordingCubit, RecordingState>(
        listener: (context, recState) {
          if (recState is RecordingSuccess) {
            context.read<SpeechCubit>().translateAudio(
              audioFilePath: recState.filePath,
              srcLang: widget.srcLang,
              tgtLang: widget.tgtLang,
            );
          }
        },
        child: BlocBuilder<SpeechCubit, SpeechState>(
          builder: (context, speechState) {
            return BlocBuilder<RecordingCubit, RecordingState>(
              builder: (context, recState) {
                final isRecording = recState is RecordingInProgress;
                final isTranslating =
                    speechState is SpeechTranslating ||
                    speechState is SpeechRetranslating;

                return PopScope(
                  canPop: !isTranslating,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
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
                        _buildLangBar(cs, speechState),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 200,
                          child: _buildVisualiser(
                            cs,
                            isRecording,
                            isTranslating,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildStatusArea(cs, theme, speechState, recState),
                        const SizedBox(height: 28),
                        _buildControls(
                          cs,
                          speechState,
                          recState,
                          isTranslating,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // =========================================================================
  // Language bar
  // =========================================================================

  Widget _buildLangBar(ColorScheme cs, SpeechState state) {
    String src = widget.srcLang, tgt = widget.tgtLang;
    if (state is SpeechSuccess) {
      src = state.srcLang;
      tgt = state.tgtLang;
    }
    if (state is SpeechTranslating) {
      src = state.srcLang;
      tgt = state.tgtLang;
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
  // Visualiser
  // =========================================================================

  Widget _buildVisualiser(
    ColorScheme cs,
    bool isRecording,
    bool isTranslating,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (!isTranslating)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => CustomPaint(
              size: const Size(200, 200),
              painter: _PulseRingPainter(
                progress: _pulseCtrl.value,
                color: isRecording ? AppTheme.primaryColor : cs.outlineVariant,
                isRecording: isRecording,
              ),
            ),
          ),
        if (isRecording)
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, child) => CustomPaint(
              size: const Size(200, 200),
              painter: _WaveBarPainter(
                animValue: _waveCtrl.value,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        if (isTranslating)
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primaryColor,
            ),
          ),
        _MicButton(
          isRecording: isRecording,
          isTranslating: isTranslating,
          onTap: isTranslating
              ? null
              : () {
                  final rec = context.read<RecordingCubit>();
                  if (isRecording) {
                    rec.stopRecording();
                  } else {
                    context.read<SpeechCubit>().reset();
                    rec.startRecording();
                  }
                },
        ),
      ],
    );
  }

  // =========================================================================
  // Status area
  // =========================================================================

  Widget _buildStatusArea(
    ColorScheme cs,
    ThemeData theme,
    SpeechState speechState,
    RecordingState recState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _statusContent(cs, theme, speechState, recState),
      ),
    );
  }

  Widget _statusContent(
    ColorScheme cs,
    ThemeData theme,
    SpeechState speechState,
    RecordingState recState,
  ) {
    // Recording states
    if (recState is RecordingInProgress) {
      final secs = recState.elapsed.inSeconds;
      final m = (secs ~/ 60).toString().padLeft(2, '0');
      final s = (secs % 60).toString().padLeft(2, '0');
      return Column(
        key: const ValueKey('recording'),
        children: [
          Text(
            'Đang ghi âm...',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$m:$s',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      );
    }
    if (recState is RecordingPermissionDenied) {
      return Column(
        key: const ValueKey('perm'),
        children: [
          Icon(Icons.mic_off_rounded, color: cs.error, size: 32),
          const SizedBox(height: 8),
          Text(
            'Cần quyền truy cập microphone.',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    if (recState is RecordingFailure) {
      return Column(
        key: const ValueKey('rec_fail'),
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 32),
          const SizedBox(height: 8),
          Text(
            'Lỗi mic: ${recState.message}',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Speech states
    switch (speechState) {
      case SpeechInitial():
        return Text(
          'Bấm mic để bắt đầu ghi âm',
          key: const ValueKey('idle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        );
      case SpeechListening():
        return const SizedBox.shrink(key: ValueKey('listening'));
      case SpeechTranslating():
        return Column(
          key: const ValueKey('translating'),
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Đang nhận diện giọng nói và dịch...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      case SpeechRetranslating(editedText: final text):
        return Column(
          key: const ValueKey('retranslating'),
          children: [
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Đang dịch lại...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      case SpeechSuccess():
        return _ResultCard(
          key: const ValueKey('success'),
          sourceText: speechState.recognisedText,
          translatedText: speechState.translatedText,
          srcLang: speechState.srcLang,
          tgtLang: speechState.tgtLang,
          onCopySource: () => _copyText(
            speechState.recognisedText,
            'Đã sao chép văn bản nguồn',
          ),
          onCopyTranslation: () =>
              _copyText(speechState.translatedText, 'Đã sao chép bản dịch'),
          onEditSource: () => _showEditDialog(
            speechState.recognisedText,
            speechState.srcLang,
            speechState.tgtLang,
          ),
          theme: theme,
          cs: cs,
        );
      case SpeechFailure(message: final msg):
        return Column(
          key: const ValueKey('failure'),
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 32),
            const SizedBox(height: 8),
            Text(
              msg,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }

  // =========================================================================
  // Edit source text dialog
  // =========================================================================

  Future<void> _showEditDialog(
    String currentText,
    String srcLang,
    String tgtLang,
  ) async {
    final controller = TextEditingController(text: currentText);
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Sửa văn bản gốc'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Chỉnh sửa nội dung nhận diện...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                final edited = controller.text.trim();
                if (edited.isNotEmpty && edited != currentText) {
                  context.read<SpeechCubit>().retranslate(
                    editedText: edited,
                    srcLang: srcLang,
                    tgtLang: tgtLang,
                  );
                }
              },
              child: const Text('Dịch lại'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // =========================================================================
  // Controls
  // =========================================================================

  Widget _buildControls(
    ColorScheme cs,
    SpeechState speechState,
    RecordingState recState,
    bool isTranslating,
  ) {
    final isRecording = recState is RecordingInProgress;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: Icons.close_rounded,
          label: 'Đóng',
          color: cs.onSurfaceVariant,
          bgColor: cs.surfaceContainerHighest,
          onTap: isTranslating
              ? null
              : () {
                  context.read<RecordingCubit>().cancelRecording();
                  context.read<SpeechCubit>().reset();
                  Navigator.of(context).pop();
                },
        ),
        if (speechState is SpeechSuccess) ...[
          const SizedBox(width: 24),
          _ControlBtn(
            icon: Icons.bookmark_add_outlined,
            label: 'Lưu từ',
            color: Colors.white,
            bgColor: AppTheme.secondaryColor,
            onTap: () {
              showSaveVocabularyDialog(
                context: context,
                cubit: context.read<VocabularyCubit>(),
                word: speechState.recognisedText,
                translation: speechState.translatedText,
                sourceLanguage: speechState.srcLang,
                targetLanguage: speechState.tgtLang,
              );
            },
          ),
        ],
        if (speechState is SpeechSuccess ||
            speechState is SpeechFailure ||
            isRecording)
          const SizedBox(width: 24)
        else
          const SizedBox(width: 32),
        if (speechState is SpeechSuccess || speechState is SpeechFailure)
          _ControlBtn(
            icon: Icons.refresh_rounded,
            label: 'Thử lại',
            color: Colors.white,
            bgColor: AppTheme.primaryColor,
            onTap: () {
              context.read<SpeechCubit>().reset();
              context.read<RecordingCubit>().startRecording();
            },
          ),
        if (isRecording)
          _ControlBtn(
            icon: Icons.stop_rounded,
            label: 'Dừng',
            color: Colors.white,
            bgColor: AppTheme.primaryColor,
            onTap: () => context.read<RecordingCubit>().stopRecording(),
          ),
      ],
    );
  }
}

// ===========================================================================
// Mic button
// ===========================================================================

class _MicButton extends StatelessWidget {
  final bool isRecording;
  final bool isTranslating;
  final VoidCallback? onTap;

  const _MicButton({
    required this.isRecording,
    required this.isTranslating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isRecording
              ? LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color: isRecording
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: isRecording ? 24 : 8,
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
    );
  }
}

// ===========================================================================
// Custom painters
// ===========================================================================

class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isRecording;

  _PulseRingPainter({
    required this.progress,
    required this.color,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final t = ((progress - i / 3) % 1.0 + 1.0) % 1.0;
      final radius = 44.0 + 46.0 * t;
      final opacity = (1.0 - t) * (isRecording ? 0.5 : 0.35);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = isRecording ? 2.5 : 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.progress != progress || old.isRecording != isRecording;
}

class _WaveBarPainter extends CustomPainter {
  final double animValue;
  final Color color;
  static const _barCount = 28;

  _WaveBarPainter({required this.animValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2, centerY = size.height / 2;
    const bw = 4.0, bs = 5.0;
    final tw = _barCount * (bw + bs) - bs;
    final sx = centerX - tw / 2;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bw;
    final rng = math.Random(42);
    for (int i = 0; i < _barCount; i++) {
      final x = sx + i * (bw + bs) + bw / 2;
      final phase = rng.nextDouble() * math.pi * 2;
      final ba = (math.sin(animValue * math.pi * 2 + phase) + 1) / 2;
      final h = 6.0 + (size.height * 0.38 - 6.0) * (0.5 + ba * 0.5);
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveBarPainter old) => old.animValue != animValue;
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
  final VoidCallback? onTap;
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
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color == Colors.white ? bgColor : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Result card with edit button
// ===========================================================================

class _ResultCard extends StatelessWidget {
  final String sourceText;
  final String translatedText;
  final String srcLang;
  final String tgtLang;
  final VoidCallback onCopySource;
  final VoidCallback onCopyTranslation;
  final VoidCallback onEditSource;
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
    required this.onEditSource,
    required this.theme,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Source text card
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit button — allows user to fix STT mistakes
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    tooltip: 'Sửa văn bản gốc',
                    color: cs.onSurfaceVariant,
                    onPressed: onEditSource,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
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
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: cs.primary,
              size: 22,
            ),
          ),
        ),
        // Translation card
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
