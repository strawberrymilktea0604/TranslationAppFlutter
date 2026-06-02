import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';

/// A single answer option tile with interactive feedback.
///
/// Shows:
/// - Letter label (A, B, C, D...)
/// - Option text
/// - Color feedback after selection:
///   ✅ Green for correct answer
///   ❌ Red for incorrect answer
///   🟢 Green outline for the correct answer (if user chose wrong)
class QuizOptionTile extends StatelessWidget {
  final QuizOptionEntity option;
  final int index;
  final bool isSelected;
  final bool hasAnswered;
  final bool showFeedback;
  final VoidCallback? onTap;

  const QuizOptionTile({
    super.key,
    required this.option,
    required this.index,
    required this.isSelected,
    required this.hasAnswered,
    this.showFeedback = false,
    this.onTap,
  });

  /// Maps index to letter label (A, B, C, D...).
  String get _label => String.fromCharCode(65 + index);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine colors based on answer state.
    Color backgroundColor;
    Color borderColor;
    Color labelBgColor;
    Color labelTextColor;
    IconData? trailingIcon;
    Color? trailingColor;

    if (hasAnswered && !showFeedback) {
      if (isSelected) {
        backgroundColor = AppTheme.primaryColor.withValues(alpha: 0.1);
        borderColor = AppTheme.primaryColor;
        labelBgColor = AppTheme.primaryColor;
        labelTextColor = Colors.white;
        trailingIcon = Icons.radio_button_checked_rounded;
        trailingColor = AppTheme.primaryColor;
      } else {
        backgroundColor = isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.04);
        borderColor = Colors.grey.withValues(alpha: 0.18);
        labelBgColor = Colors.grey.withValues(alpha: 0.1);
        labelTextColor = Colors.grey;
        trailingIcon = null;
        trailingColor = null;
      }
    } else if (hasAnswered) {
      if (isSelected && option.isCorrect) {
        // Selected & correct → green.
        backgroundColor = AppTheme.successColor.withValues(alpha: 0.1);
        borderColor = AppTheme.successColor;
        labelBgColor = AppTheme.successColor;
        labelTextColor = Colors.white;
        trailingIcon = Icons.check_circle_rounded;
        trailingColor = AppTheme.successColor;
      } else if (isSelected && !option.isCorrect) {
        // Selected & wrong → red.
        backgroundColor = AppTheme.errorColor.withValues(alpha: 0.1);
        borderColor = AppTheme.errorColor;
        labelBgColor = AppTheme.errorColor;
        labelTextColor = Colors.white;
        trailingIcon = Icons.cancel_rounded;
        trailingColor = AppTheme.errorColor;
      } else if (!isSelected && option.isCorrect) {
        // Not selected but is correct → highlight green.
        backgroundColor = AppTheme.successColor.withValues(alpha: 0.05);
        borderColor = AppTheme.successColor.withValues(alpha: 0.5);
        labelBgColor = AppTheme.successColor.withValues(alpha: 0.15);
        labelTextColor = AppTheme.successColor;
        trailingIcon = Icons.check_circle_outline_rounded;
        trailingColor = AppTheme.successColor.withValues(alpha: 0.6);
      } else {
        // Not selected & not correct → dim.
        backgroundColor = isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.05);
        borderColor = Colors.grey.withValues(alpha: 0.2);
        labelBgColor = Colors.grey.withValues(alpha: 0.1);
        labelTextColor = Colors.grey;
        trailingIcon = null;
        trailingColor = null;
      }
    } else {
      // Not answered yet — default state.
      backgroundColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white;
      borderColor = cs.outlineVariant.withValues(alpha: 0.5);
      labelBgColor = AppTheme.primaryColor.withValues(alpha: 0.08);
      labelTextColor = AppTheme.primaryColor;
      trailingIcon = null;
      trailingColor = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: borderColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Letter label circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: labelBgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: labelTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Option text
                Expanded(
                  child: Text(
                    option.text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color:
                          hasAnswered &&
                              !isSelected &&
                              (!showFeedback || !option.isCorrect)
                          ? cs.onSurface.withValues(alpha: 0.4)
                          : cs.onSurface,
                    ),
                  ),
                ),

                // Trailing icon
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailingIcon, size: 22, color: trailingColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
