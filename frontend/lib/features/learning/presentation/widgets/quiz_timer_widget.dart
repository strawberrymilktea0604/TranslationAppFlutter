import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/app_theme.dart';

/// Animated countdown timer widget displayed in the AppBar.
///
/// Features:
/// - Shows MM:SS format
/// - Warning state (< 60s): orange pulsing
/// - Critical state (< 10s): red pulsing with scale animation
class QuizTimerWidget extends StatefulWidget {
  final int remainingSeconds;
  final bool isWarning;
  final bool isCritical;

  const QuizTimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.isWarning,
    required this.isCritical,
  });

  @override
  State<QuizTimerWidget> createState() => _QuizTimerWidgetState();
}

class _QuizTimerWidgetState extends State<QuizTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant QuizTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCritical && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCritical && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    if (widget.isCritical) {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.15);
      textColor = AppTheme.errorColor;
      icon = Icons.warning_amber_rounded;
    } else if (widget.isWarning) {
      bgColor = AppTheme.warningColor.withValues(alpha: 0.15);
      textColor = AppTheme.warningColor;
      icon = Icons.timer_outlined;
    } else {
      bgColor = Colors.white.withValues(alpha: 0.15);
      textColor = Colors.white;
      icon = Icons.timer_outlined;
    }

    final timerContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: widget.isCritical
            ? Border.all(color: AppTheme.errorColor, width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            _formatTime(widget.remainingSeconds),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    if (widget.isCritical) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: timerContent,
      );
    }

    return timerContent;
  }
}
