import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/tts/bloc/tts_cubit.dart';
import 'package:frontend/core/tts/bloc/tts_state.dart';

/// A self-contained icon button that triggers TTS playback.
///
/// Displays a speaker icon that toggles between idle and speaking
/// states. When speaking the associated text, the icon animates
/// to indicate active playback.
///
/// Requires a [TtsCubit] to be available in the widget tree
/// (provided at the app or page level).
class TtsIconButton extends StatelessWidget {
  /// The text to be spoken.
  final String text;

  /// The language code for voice selection (e.g. 'en', 'vi', 'ja').
  final String languageCode;

  /// Icon size. Defaults to 20.
  final double iconSize;

  /// Icon color when idle. Defaults to theme's onSurfaceVariant.
  final Color? idleColor;

  /// Icon color when actively speaking. Defaults to theme's primary.
  final Color? activeColor;

  /// Optional tooltip text.
  final String? tooltip;

  const TtsIconButton({
    super.key,
    required this.text,
    required this.languageCode,
    this.iconSize = 20,
    this.idleColor,
    this.activeColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedIdleColor = idleColor ?? cs.onSurfaceVariant;
    final resolvedActiveColor = activeColor ?? cs.primary;
    final hasText = text.trim().isNotEmpty;

    return BlocBuilder<TtsCubit, TtsState>(
      buildWhen: (previous, current) {
        // Only rebuild when this button's speaking state changes.
        final wasSpeaking = previous is TtsSpeaking &&
            previous.text == text &&
            previous.languageCode == languageCode;
        final isSpeaking = current is TtsSpeaking &&
            current.text == text &&
            current.languageCode == languageCode;
        return wasSpeaking != isSpeaking;
      },
      builder: (context, state) {
        final isSpeaking = state is TtsSpeaking &&
            state.text == text &&
            state.languageCode == languageCode;

        return IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSpeaking
                  ? Icons.stop_circle_outlined
                  : Icons.volume_up_outlined,
              key: ValueKey(isSpeaking),
              size: iconSize,
            ),
          ),
          tooltip: tooltip ?? (isSpeaking ? 'Dừng phát âm' : 'Phát âm'),
          color: isSpeaking ? resolvedActiveColor : resolvedIdleColor,
          onPressed: hasText
              ? () => context.read<TtsCubit>().speak(
                    text: text,
                    languageCode: languageCode,
                  )
              : null,
        );
      },
    );
  }
}
