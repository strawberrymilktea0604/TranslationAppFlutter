import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/features/conversation/presentation/bloc/conversation_viewmodel.dart';

/// A compact status bar showing the current session lifecycle status
/// with an animated transition between states.
///
/// Displays:
/// - 🔵 Idle / Ready — "Sẵn sàng"
/// - 🔴 Recording — "Đang nghe..." (pulsing)
/// - 🟡 Processing — "Đang xử lý..." (spinner)
/// - ✅ Ended — "Đã kết thúc"
class SessionStatusBar extends StatefulWidget {
  /// Current session lifecycle status.
  final SessionLifecycleStatus status;

  /// Current volume level (used for recording animation).
  final double volumeLevel;

  const SessionStatusBar({
    super.key,
    required this.status,
    this.volumeLevel = 0.0,
  });

  @override
  State<SessionStatusBar> createState() => _SessionStatusBarState();
}

class _SessionStatusBarState extends State<SessionStatusBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(SessionStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.status == SessionLifecycleStatus.recording) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _statusInfo(widget.status);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey(widget.status),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.status == SessionLifecycleStatus.processing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final opacity = widget.status ==
                          SessionLifecycleStatus.recording
                      ? (0.5 + _pulseController.value * 0.5)
                      : 1.0;
                  return Opacity(
                    opacity: opacity,
                    child: Icon(icon, size: 14, color: color),
                  );
                },
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData, String) _statusInfo(SessionLifecycleStatus status) {
    return switch (status) {
      SessionLifecycleStatus.idle => (
          const Color(0xFF9E9E9E),
          Icons.mic_none_rounded,
          'Chờ bắt đầu',
        ),
      SessionLifecycleStatus.ready => (
          const Color(0xFF4CAF50),
          Icons.check_circle_outline_rounded,
          'Sẵn sàng',
        ),
      SessionLifecycleStatus.recording => (
          const Color(0xFFF44336),
          Icons.fiber_manual_record,
          'Đang nghe...',
        ),
      SessionLifecycleStatus.processing => (
          const Color(0xFFFF9800),
          Icons.hourglass_top_rounded,
          'Đang xử lý...',
        ),
      SessionLifecycleStatus.ended => (
          const Color(0xFF9E9E9E),
          Icons.stop_circle_outlined,
          'Đã kết thúc',
        ),
    };
  }
}
