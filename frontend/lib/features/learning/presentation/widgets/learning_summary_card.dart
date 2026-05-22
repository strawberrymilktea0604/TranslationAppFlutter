import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/learning/domain/entities/learning_summary_entity.dart';

/// Header card for the Learning Dashboard showing overall
/// learning progress with an animated circular progress ring.
///
/// Displays: total words, learned words, quizzes completed,
/// average score.
class LearningSummaryCard extends StatelessWidget {
  final LearningSummaryEntity summary;

  const LearningSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = summary.vocabularyProgress;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A237E),
                  const Color(0xFF0D47A1),
                ]
              : [
                  AppTheme.primaryColor,
                  const Color(0xFF1565C0),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiến độ học tập',
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _progressSubtitle(progress),
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stats row: Ring + counters
          Row(
            children: [
              // Circular progress ring
              _ProgressRing(
                progress: progress,
                totalWords: summary.totalWords,
                learnedWords: summary.learnedWords,
              ),
              const SizedBox(width: 24),
              // Stat counters
              Expanded(
                child: Column(
                  children: [
                    _StatItem(
                      icon: Icons.menu_book_rounded,
                      label: 'Tổng từ vựng',
                      value: summary.totalWords.toString(),
                    ),
                    const SizedBox(height: 10),
                    _StatItem(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Đã thuộc',
                      value: summary.learnedWords.toString(),
                    ),
                    const SizedBox(height: 10),
                    _StatItem(
                      icon: Icons.quiz_outlined,
                      label: 'Đề đã làm',
                      value: summary.quizzesCompleted.toString(),
                    ),
                    const SizedBox(height: 10),
                    _StatItem(
                      icon: Icons.trending_up_rounded,
                      label: 'Điểm TB',
                      value: summary.averageScore == 0
                          ? '--'
                          : '${summary.averageScore.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _progressSubtitle(double progress) {
    if (progress >= 80) return 'Xuất sắc! Hãy tiếp tục phát huy 🎉';
    if (progress >= 50) return 'Tiến bộ tốt! Cố gắng thêm nhé 💪';
    if (progress > 0) return 'Bạn đang trên đường tiến bộ ✨';
    return 'Bắt đầu học từ vựng nào! 🚀';
  }
}

/// Animated circular progress ring for vocabulary progress.
class _ProgressRing extends StatefulWidget {
  final double progress;
  final int totalWords;
  final int learnedWords;

  const _ProgressRing({
    required this.progress,
    required this.totalWords,
    required this.learnedWords,
  });

  @override
  State<_ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<_ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animatedProgress =
            widget.progress * _animation.value / 100;
        return SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _RingPainter(
              progress: animatedProgress,
              color: Colors.white,
              trackColor: Colors.white.withValues(alpha: 0.15),
              strokeWidth: 8,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(widget.progress * _animation.value).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${widget.learnedWords}/${widget.totalWords}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom ring painter for circular progress.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Single stat item within the summary card.
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
