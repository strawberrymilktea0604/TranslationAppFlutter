import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/learning/presentation/bloc/quiz_state.dart';

/// Bottom sheet showing quiz results after submission.
///
/// Displays:
/// - Score percentage with circular indicator
/// - Correct/wrong/unanswered counts
/// - Auto-submit notice if applicable
/// - "Đóng" (Close) button to dismiss and go back
class QuizResultSheet extends StatelessWidget {
  final QuizState state;

  const QuizResultSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = state.scorePercentage;
    final correct = state.correctCount;
    final wrong = state.answeredCount - correct;
    final unanswered = state.questions.length - state.answeredCount;

    // Determine score color.
    Color scoreColor;
    String scoreEmoji;
    String scoreLabel;
    if (score >= 80) {
      scoreColor = AppTheme.successColor;
      scoreEmoji = '🎉';
      scoreLabel = 'Xuất sắc!';
    } else if (score >= 60) {
      scoreColor = AppTheme.warningColor;
      scoreEmoji = '👍';
      scoreLabel = 'Khá tốt!';
    } else {
      scoreColor = AppTheme.errorColor;
      scoreEmoji = '💪';
      scoreLabel = 'Cần cố gắng thêm!';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Auto-submit notice
            if (state.isAutoSubmitted) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_off_rounded,
                      size: 16,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Bài thi đã được nộp tự động do hết giờ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Emoji + label
            Text(scoreEmoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              scoreLabel,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 24),

            // Score circle
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scoreColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        '$correct/${state.questions.length}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  icon: Icons.check_circle_rounded,
                  color: AppTheme.successColor,
                  value: '$correct',
                  label: 'Đúng',
                ),
                _StatItem(
                  icon: Icons.cancel_rounded,
                  color: AppTheme.errorColor,
                  value: '$wrong',
                  label: 'Sai',
                ),
                _StatItem(
                  icon: Icons.help_outline_rounded,
                  color: Colors.grey,
                  value: '$unanswered',
                  label: 'Bỏ qua',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Close button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.pop(context); // Go back to dashboard
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Đóng',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single stat item (correct/wrong/unanswered).
class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
