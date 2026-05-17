import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Data class holding quiz result info — can come from QuizResultModel or
// be constructed on-the-fly for Flashcard review mode.
// ---------------------------------------------------------------------------

/// A single wrong answer the user gave.
class QuizWrongAnswer {
  final String questionText;
  final String userAnswer;
  final String correctAnswer;

  const QuizWrongAnswer({
    required this.questionText,
    required this.userAnswer,
    required this.correctAnswer,
  });
}

/// Data bundle passed to [QuizResultPage].
class QuizResultData {
  /// Title of the quiz / flashcard set.
  final String title;

  /// Total number of questions.
  final int totalQuestions;

  /// Number of correct answers.
  final int correctAnswers;

  /// Percentage score (0.0 – 100.0).
  final double score;

  /// Time the user actually took (seconds).
  final int durationSeconds;

  /// Time limit for the quiz (seconds). 0 = no limit.
  final int timeLimitSeconds;

  /// List of wrong answers for review.
  final List<QuizWrongAnswer> wrongAnswers;

  /// 'completed' or 'timeout'.
  final String? status;

  const QuizResultData({
    required this.title,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.durationSeconds,
    this.timeLimitSeconds = 0,
    this.wrongAnswers = const [],
    this.status,
  });

  int get wrongCount => totalQuestions - correctAnswers;
}

// ---------------------------------------------------------------------------
// QuizResultPage — the main widget
// ---------------------------------------------------------------------------

/// Displays quiz / flashcard results with:
/// - Animated circular progress chart (score)
/// - Correct / Wrong breakdown
/// - Time taken vs time limit
/// - Expandable list of wrong answers for review
///
/// Design: matches AppTheme (Material 3, Inter font, rounded cards,
/// primaryColor = #1976D2, successColor = #4CAF50, errorColor = #F44336).
class QuizResultPage extends StatefulWidget {
  final QuizResultData data;

  /// Called when the user taps "Làm lại".
  final VoidCallback? onRetry;

  /// Called when the user taps "Về trang chủ".
  final VoidCallback? onGoHome;

  const QuizResultPage({
    super.key,
    required this.data,
    this.onRetry,
    this.onGoHome,
  });

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final Animation<double> _ringAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Circular ring fill animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnimation = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );

    // Fade-in for content below the ring
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Stagger: ring first, then fade-in
    _ringController.forward();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Helpers ----------------------------------------------------------------

  Color _scoreColor(double score) {
    if (score >= 80) return AppTheme.successColor;
    if (score >= 50) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  String _emoji(double score) {
    if (score == 100) return '🎉';
    if (score >= 80) return '👏';
    if (score >= 50) return '💪';
    return '😢';
  }

  String _headline(double score) {
    if (score == 100) return 'Hoàn hảo!';
    if (score >= 80) return 'Bạn đã làm được!';
    if (score >= 50) return 'Khá tốt!';
    return 'Cần cố gắng thêm!';
  }

  String _subtitle(double score) {
    if (score == 100) return 'Tuyệt vời! Bạn trả lời đúng tất cả.';
    if (score >= 80) return 'Đã hoàn thành bài kiểm tra.';
    if (score >= 50) return 'Tiếp tục luyện tập để cải thiện nhé!';
    return 'Hãy ôn lại những câu sai bên dưới.';
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scoreCol = _scoreColor(d.score);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.title),
        leading: widget.onGoHome != null
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: widget.onGoHome,
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // === Header + Emoji ===
            Center(
              child: Text(
                _emoji(d.score),
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _headline(d.score),
              textAlign: TextAlign.center,
              style: textTheme.displayMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle(d.score),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // === Score ring + stats ===
            _ScoreSection(
              ringAnimation: _ringAnimation,
              data: d,
              scoreColor: scoreCol,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // === Time info ===
            FadeTransition(
              opacity: _fadeAnimation,
              child: _TimeCard(
                data: d,
                isDark: isDark,
                formatDuration: _formatDuration,
              ),
            ),

            // === Wrong answers ===
            if (d.wrongAnswers.isNotEmpty) ...[
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fadeAnimation,
                child: _WrongAnswersSection(
                  wrongAnswers: d.wrongAnswers,
                  isDark: isDark,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // === Action buttons ===
            FadeTransition(
              opacity: _fadeAnimation,
              child: _ActionButtons(
                onRetry: widget.onRetry,
                onGoHome: widget.onGoHome,
                hasWrongAnswers: d.wrongAnswers.isNotEmpty,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score section — ring + stats row
// ---------------------------------------------------------------------------

class _ScoreSection extends StatelessWidget {
  final Animation<double> ringAnimation;
  final QuizResultData data;
  final Color scoreColor;
  final bool isDark;

  const _ScoreSection({
    required this.ringAnimation,
    required this.data,
    required this.scoreColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // --- Animated ring ---
        AnimatedBuilder(
          animation: ringAnimation,
          builder: (context, child) {
            final animatedScore = data.score * ringAnimation.value;
            return SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: animatedScore / 100,
                  color: scoreColor,
                  trackColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 12,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${data.correctAnswers}/${data.totalQuestions}',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        '${animatedScore.toStringAsFixed(0)}%',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 32),

        // --- Correct / Wrong counters ---
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(
              icon: Icons.check_circle_rounded,
              iconColor: AppTheme.successColor,
              label: 'Đúng',
              value: data.correctAnswers.toString(),
              textTheme: textTheme,
            ),
            const SizedBox(height: 16),
            _StatRow(
              icon: Icons.cancel_rounded,
              iconColor: AppTheme.errorColor,
              label: 'Sai',
              value: data.wrongCount.toString(),
              textTheme: textTheme,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final TextTheme textTheme;

  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 8),
        Text(label,
            style: textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Time card
// ---------------------------------------------------------------------------

class _TimeCard extends StatelessWidget {
  final QuizResultData data;
  final bool isDark;
  final String Function(int) formatDuration;

  const _TimeCard({
    required this.data,
    required this.isDark,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasLimit = data.timeLimitSeconds > 0;
    final timeText = hasLimit
        ? '${formatDuration(data.durationSeconds)} / ${formatDuration(data.timeLimitSeconds)}'
        : formatDuration(data.durationSeconds);

    // Progress ratio for the time bar
    final timeRatio = hasLimit
        ? (data.durationSeconds / data.timeLimitSeconds).clamp(0.0, 1.0)
        : 1.0;

    final timeBarColor = timeRatio >= 0.9
        ? AppTheme.errorColor
        : timeRatio >= 0.7
            ? AppTheme.warningColor
            : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thời gian hoàn thành',
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeText,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.status == 'timeout')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hết giờ',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (hasLimit) ...[
            const SizedBox(height: 12),
            // Time progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: timeRatio,
                minHeight: 8,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(timeBarColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wrong answers section
// ---------------------------------------------------------------------------

class _WrongAnswersSection extends StatelessWidget {
  final List<QuizWrongAnswer> wrongAnswers;
  final bool isDark;

  const _WrongAnswersSection({
    required this.wrongAnswers,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              Icons.rate_review_outlined,
              color: AppTheme.errorColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Câu hỏi làm sai (${wrongAnswers.length})',
              style: textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Hãy ôn tập lại những câu này nhé!',
          style: textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // Wrong answer cards
        ...wrongAnswers.asMap().entries.map((entry) {
          final idx = entry.key;
          final wa = entry.value;
          return _WrongAnswerCard(
            index: idx + 1,
            wrongAnswer: wa,
            isDark: isDark,
          );
        }),
      ],
    );
  }
}

class _WrongAnswerCard extends StatelessWidget {
  final int index;
  final QuizWrongAnswer wrongAnswer;
  final bool isDark;

  const _WrongAnswerCard({
    required this.index,
    required this.wrongAnswer,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wrongAnswer.questionText,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // User's wrong answer
          _AnswerRow(
            icon: Icons.close_rounded,
            iconColor: AppTheme.errorColor,
            label: 'Bạn chọn:',
            answer: wrongAnswer.userAnswer,
            bgColor: AppTheme.errorColor.withValues(alpha: 0.06),
            textColor: AppTheme.errorColor,
          ),
          const SizedBox(height: 6),

          // Correct answer
          _AnswerRow(
            icon: Icons.check_rounded,
            iconColor: AppTheme.successColor,
            label: 'Đáp án:',
            answer: wrongAnswer.correctAnswer,
            bgColor: AppTheme.successColor.withValues(alpha: 0.06),
            textColor: AppTheme.successColor,
          ),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String answer;
  final Color bgColor;
  final Color textColor;

  const _AnswerRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.answer,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: iconColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              answer,
              style: textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;
  final bool hasWrongAnswers;

  const _ActionButtons({
    this.onRetry,
    this.onGoHome,
    this.hasWrongAnswers = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary: Retry
        if (onRetry != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Làm lại'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

        if (onRetry != null && onGoHome != null) const SizedBox(height: 12),

        // Secondary: Go home
        if (onGoHome != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGoHome,
              icon: const Icon(Icons.home_rounded),
              label: const Text('Về trang chủ'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Custom ring painter
// ---------------------------------------------------------------------------

class _RingPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
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
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
