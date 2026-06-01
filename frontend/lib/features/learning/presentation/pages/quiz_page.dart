import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/features/learning/presentation/bloc/quiz_cubit.dart';
import 'package:frontend/features/learning/presentation/bloc/quiz_state.dart';
import 'package:frontend/features/learning/presentation/widgets/quiz_timer_widget.dart';
import 'package:frontend/features/learning/presentation/widgets/quiz_option_tile.dart';
import 'package:frontend/features/learning/presentation/widgets/quiz_result_sheet.dart';
import 'package:frontend/injection_container.dart';

/// Quiz Engine page — displays questions with countdown timer.
///
/// Features:
/// 1. Countdown Timer using Stream.periodic
/// 2. Auto-submit when timer reaches 0
/// 3. Interactive Feedback (color + haptic)
///
/// Uses BlocProvider to scope the QuizCubit locally.
class QuizPage extends StatelessWidget {
  /// Questions to display (passed from dashboard).
  final List<QuizQuestionEntity> initialQuestions;

  /// Quiz duration in seconds.
  final int durationSeconds;

  /// Bank ID for result submission.
  final String bankId;

  /// Bank title for display.
  final String bankTitle;

  const QuizPage({
    super.key,
    required this.initialQuestions,
    required this.durationSeconds,
    this.bankId = '',
    this.bankTitle = 'Quiz',
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = sl<QuizCubit>();
        if (initialQuestions.isNotEmpty) {
          cubit.startQuiz(initialQuestions, durationSeconds, bankId: bankId);
        } else {
          cubit.loadAndStartQuiz(
            bankId: bankId,
            durationSeconds: durationSeconds,
          );
        }
        return cubit;
      },
      child: _QuizView(bankTitle: bankTitle),
    );
  }
}

class _QuizView extends StatelessWidget {
  final String bankTitle;

  const _QuizView({required this.bankTitle});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QuizCubit, QuizState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == QuizStatus.submitted) {
          // Haptic feedback on submit.
          HapticFeedback.heavyImpact();

          // Show result bottom sheet.
          showModalBottomSheet<void>(
            context: context,
            isDismissible: false,
            enableDrag: false,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => QuizResultSheet(state: state),
          );
        }
      },
      builder: (context, state) {
        if (state.questions.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(bankTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return _QuizScaffold(bankTitle: bankTitle, state: state);
      },
    );
  }
}

/// Main quiz scaffold with AppBar, timer, question, and navigation.
class _QuizScaffold extends StatelessWidget {
  final String bankTitle;
  final QuizState state;

  const _QuizScaffold({required this.bankTitle, required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSubmitted = state.status == QuizStatus.submitted;
    final question = state.questions[state.currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(bankTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _showExitDialog(context),
        ),
        actions: [
          QuizTimerWidget(
            remainingSeconds: state.remainingSeconds,
            isWarning: state.isWarningTime,
            isCritical: state.isCriticalTime,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IgnorePointer(
        ignoring: isSubmitted,
        child: Column(
          children: [
            // Progress bar
            _QuizProgressBar(state: state),

            // Question content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number badge
                    _QuestionBadge(state: state),
                    const SizedBox(height: 12),

                    // Question text
                    Text(
                      question.content,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Options
                    ...List.generate(question.options.length, (i) {
                      final option = question.options[i];
                      final isSelected =
                          state.selectedAnswers[question.id] == option.id;
                      final hasAnswered = state.selectedAnswers.containsKey(
                        question.id,
                      );

                      return QuizOptionTile(
                        option: option,
                        index: i,
                        isSelected: isSelected,
                        hasAnswered: hasAnswered,
                        onTap: hasAnswered
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                context.read<QuizCubit>().selectAnswer(
                                  question.id,
                                  option.id,
                                );
                              },
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom navigation
            _BottomNavBar(state: state),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thoát bài thi?'),
        content: const Text('Bài làm của bạn sẽ được nộp tự động nếu thoát.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tiếp tục làm'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<QuizCubit>().submitQuiz();
            },
            child: const Text('Nộp và thoát'),
          ),
        ],
      ),
    );
  }
}

/// Animated progress bar showing quiz completion.
class _QuizProgressBar extends StatelessWidget {
  final QuizState state;

  const _QuizProgressBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (state.currentQuestionIndex + 1) / state.questions.length;

    return Container(
      height: 4,
      color: cs.surfaceContainerHighest,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Question number and answered status badge.
class _QuestionBadge extends StatelessWidget {
  final QuizState state;

  const _QuestionBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Câu ${state.currentQuestionIndex + 1}/${state.questions.length}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${state.answeredCount}/${state.questions.length} đã trả lời',
          style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Bottom navigation bar with Previous/Next/Submit buttons
/// and question dots indicator.
class _BottomNavBar extends StatelessWidget {
  final QuizState state;

  const _BottomNavBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = state.currentQuestionIndex >= state.questions.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Question dots
          _QuestionDots(state: state),
          const SizedBox(height: 12),

          // Nav buttons
          Row(
            children: [
              // Previous
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.currentQuestionIndex > 0
                      ? () => context.read<QuizCubit>().previousQuestion()
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Trước'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Next or Submit
              Expanded(
                child: isLast
                    ? FilledButton.icon(
                        onPressed: () => context.read<QuizCubit>().submitQuiz(),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Nộp bài'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: () =>
                            context.read<QuizCubit>().nextQuestion(),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Tiếp'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrollable question dots indicator.
class _QuestionDots extends StatelessWidget {
  final QuizState state;

  const _QuestionDots({required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.questions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final q = state.questions[index];
          final isCurrent = index == state.currentQuestionIndex;
          final isAnswered = state.selectedAnswers.containsKey(q.id);

          Color dotColor;
          if (isCurrent) {
            dotColor = AppTheme.primaryColor;
          } else if (isAnswered) {
            dotColor = AppTheme.successColor;
          } else {
            dotColor = Colors.grey.shade300;
          }

          return GestureDetector(
            onTap: () => context.read<QuizCubit>().goToQuestion(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isCurrent ? 28 : 24,
              height: isCurrent ? 28 : 24,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.15),
                border: Border.all(color: dotColor, width: 2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: dotColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
