import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';

/// Displays a single exam set card with overview info:
/// - Title, description
/// - Number of questions
/// - Time limit (if any)
/// - "Bắt đầu" (Start) button
///
/// Designed as a Material 3 card with depth, rounded corners,
/// and a subtle accent bar on the left.
class QuestionBankCard extends StatelessWidget {
  final QuestionBankEntity bank;

  /// Called when the user taps "Bắt đầu" to start the quiz.
  final VoidCallback? onStart;

  const QuestionBankCard({super.key, required this.bank, this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        bank.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Description
                      if (bank.description != null &&
                          bank.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          bank.description!,
                          style: textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Info chips + Start button
                      Row(
                        children: [
                          // Question count chip
                          _InfoChip(
                            icon: Icons.help_outline_rounded,
                            label: '${bank.questionCount} câu',
                            color: AppTheme.primaryColor,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),

                          // Duration chip
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: bank.durationMinutes != null
                                ? '${bank.durationMinutes} phút'
                                : 'Không giới hạn',
                            color: bank.durationMinutes != null
                                ? AppTheme.warningColor
                                : AppTheme.successColor,
                            isDark: isDark,
                          ),

                          const Spacer(),

                          // Start button
                          _StartButton(
                            onStart: onStart,
                            enabled: bank.questionCount > 0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small chip showing icon + label for question count / duration.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated "Bắt đầu" (Start) button with gradient background.
class _StartButton extends StatelessWidget {
  final VoidCallback? onStart;
  final bool enabled;

  const _StartButton({this.onStart, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final canStart = enabled && onStart != null;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canStart ? onStart : null,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: canStart
                ? const LinearGradient(
                    colors: [AppTheme.primaryColor, Color(0xFF1565C0)],
                  )
                : null,
            color: canStart
                ? null
                : cs.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            boxShadow: canStart
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bắt đầu',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: canStart ? Colors.white : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: canStart ? Colors.white : cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
