import 'package:flutter/material.dart';

/// Animated wave indicator that responds to microphone volume level.
///
/// Renders a row of vertical bars whose heights oscillate based on
/// [volumeLevel] (0.0–1.0). Creates a visual "soundwave" effect
/// that gives the user real-time feedback while recording.
class RecordingWaveIndicator extends StatefulWidget {
  /// Current volume level (0.0 = silence, 1.0 = peak).
  final double volumeLevel;

  /// Number of wave bars to display.
  final int barCount;

  /// Colour of the wave bars.
  final Color color;

  /// Maximum height of a single bar.
  final double maxBarHeight;

  const RecordingWaveIndicator({
    super.key,
    required this.volumeLevel,
    this.barCount = 5,
    this.color = const Color(0xFFF44336),
    this.maxBarHeight = 28,
  });

  @override
  State<RecordingWaveIndicator> createState() =>
      _RecordingWaveIndicatorState();
}

class _RecordingWaveIndicatorState extends State<RecordingWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (index) {
            // Each bar has a slightly different phase to create a wave effect.
            final phase = (index / widget.barCount) + _controller.value;
            final sinValue = _sin(phase * 3.14159);

            // Combine animation phase with actual volume.
            final volume = widget.volumeLevel.clamp(0.05, 1.0);
            final height =
                (4.0 + (widget.maxBarHeight - 4.0) * sinValue * volume)
                    .clamp(4.0, widget.maxBarHeight);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: (0.5 + volume * 0.5).clamp(0.3, 1.0),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// Simple sine approximation (0 → 1 → 0) for the animation curve.
  double _sin(double x) {
    // Normalize to 0..1 range and use a parabolic approximation.
    final normalized = (x % 1.0);
    return 4 * normalized * (1 - normalized);
  }
}
