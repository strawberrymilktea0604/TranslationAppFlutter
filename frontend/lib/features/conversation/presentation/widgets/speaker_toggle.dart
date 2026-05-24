import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';

/// Toggle widget for switching between Speaker A and Speaker B.
///
/// Displays two selectable segments with the active speaker highlighted.
/// Includes smooth transition animation on switch.
class SpeakerToggle extends StatelessWidget {
  /// Currently active speaker.
  final ConversationSpeaker currentSpeaker;

  /// Callback when the user taps to switch speakers.
  final VoidCallback onToggle;

  /// Whether the toggle is interactive.
  final bool enabled;

  const SpeakerToggle({
    super.key,
    required this.currentSpeaker,
    required this.onToggle,
    this.enabled = true,
  });

  bool get _isSpeakerA => currentSpeaker == ConversationSpeaker.speakerA;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? onToggle : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? const Color(0xFF3A3A3A)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSegment(
              context,
              label: 'Speaker A',
              icon: Icons.person,
              isActive: _isSpeakerA,
              activeColor: const Color(0xFF1976D2),
              isDark: isDark,
            ),
            const SizedBox(width: 2),
            _buildSegment(
              context,
              label: 'Speaker B',
              icon: Icons.person_outline,
              isActive: !_isSpeakerA,
              activeColor: const Color(0xFF00897B),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
