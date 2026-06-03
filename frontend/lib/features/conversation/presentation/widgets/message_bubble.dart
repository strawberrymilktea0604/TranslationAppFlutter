import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';

/// Chat bubble widget for a single conversation message.
///
/// Speaker A messages are aligned left with a blue gradient.
/// Speaker B messages are aligned right with a teal gradient.
///
/// Each bubble shows:
/// - Speaker label
/// - Source text (original, smaller and italic)
/// - Translated text (larger, bold)
/// - Timestamp
///
/// Entry animation: slide + fade from the appropriate side.
class MessageBubble extends StatelessWidget {
  /// The conversation message to display.
  final ConversationMessage message;

  /// Index in the list, used for staggered animation delay.
  final int index;

  const MessageBubble({
    super.key,
    required this.message,
    this.index = 0,
  });

  bool get _isSpeakerA => message.speaker == ConversationSpeaker.speakerA;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(
            (_isSpeakerA ? -20 : 20) * (1 - value),
            0,
          ),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Align(
        alignment:
            _isSpeakerA ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: EdgeInsets.only(
            left: _isSpeakerA ? 12 : 48,
            right: _isSpeakerA ? 48 : 12,
            bottom: 8,
          ),
          child: Column(
            crossAxisAlignment: _isSpeakerA
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              // Speaker label
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSpeakerA ? Icons.person : Icons.person_outline,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSpeakerA ? 'Speaker A' : 'Speaker B',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Bubble body
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isSpeakerA
                        ? [
                            isDark
                                ? const Color(0xFF1565C0)
                                : const Color(0xFF42A5F5),
                            isDark
                                ? const Color(0xFF0D47A1)
                                : const Color(0xFF1976D2),
                          ]
                        : [
                            isDark
                                ? const Color(0xFF00695C)
                                : const Color(0xFF26A69A),
                            isDark
                                ? const Color(0xFF004D40)
                                : const Color(0xFF00897B),
                          ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(_isSpeakerA ? 4 : 16),
                    bottomRight: Radius.circular(_isSpeakerA ? 16 : 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSpeakerA
                              ? const Color(0xFF1976D2)
                              : const Color(0xFF00897B))
                          .withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source text (original)
                    Text(
                      message.sourceText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Divider
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 6),

                    // Translated text
                    Text(
                      message.translatedText,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Timestamp + cached indicator
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    if (message.isCached) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.cached,
                        size: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final h = localTime.hour.toString().padLeft(2, '0');
    final m = localTime.minute.toString().padLeft(2, '0');
    final s = localTime.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
