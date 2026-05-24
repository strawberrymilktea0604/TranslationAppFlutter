import 'package:flutter/material.dart';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';

/// A chip-style indicator showing the current WebSocket connection status.
///
/// Displays a colored dot with label text:
/// - 🟢 Connected
/// - 🟡 Connecting / Reconnecting
/// - 🔴 Disconnected / Error
///
/// The dot animates with a gentle pulse when connecting/reconnecting.
class ConnectionStatusIndicator extends StatefulWidget {
  /// Current WebSocket connection status.
  final WebSocketConnectionStatus status;

  const ConnectionStatusIndicator({
    super.key,
    required this.status,
  });

  @override
  State<ConnectionStatusIndicator> createState() =>
      _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(ConnectionStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.status == WebSocketConnectionStatus.connecting ||
        widget.status == WebSocketConnectionStatus.reconnecting) {
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
    final (color, label) = _statusInfo(widget.status);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _pulseAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  (Color, String) _statusInfo(WebSocketConnectionStatus status) {
    return switch (status) {
      WebSocketConnectionStatus.connected => (
          const Color(0xFF4CAF50),
          'Đã kết nối',
        ),
      WebSocketConnectionStatus.connecting => (
          const Color(0xFFFF9800),
          'Đang kết nối...',
        ),
      WebSocketConnectionStatus.reconnecting => (
          const Color(0xFFFF9800),
          'Đang kết nối lại...',
        ),
      WebSocketConnectionStatus.disconnected => (
          const Color(0xFFF44336),
          'Mất kết nối',
        ),
      WebSocketConnectionStatus.error => (
          const Color(0xFFF44336),
          'Lỗi kết nối',
        ),
    };
  }
}
