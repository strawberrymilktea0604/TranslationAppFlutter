import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:frontend/features/learning/domain/entities/learning_summary_entity.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';
import 'package:frontend/features/learning/domain/entities/recent_quiz_result_entity.dart';
import 'package:frontend/features/learning/presentation/bloc/learning_dashboard_cubit.dart';
import 'package:frontend/features/learning/presentation/bloc/learning_dashboard_state.dart';
import 'package:frontend/features/learning/presentation/widgets/learning_summary_card.dart';
import 'package:frontend/features/learning/presentation/widgets/category_progress_list.dart';
import 'package:frontend/features/learning/presentation/widgets/question_bank_card.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';
import 'package:frontend/features/learning/domain/entities/quiz_question_entity.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/injection_container.dart';

/// Learning Dashboard page — displays:
/// 1. Overall learning progress summary card
/// 2. Vocabulary category progress (horizontal scroll)
/// 3. Available question banks / exam sets with overview info
///
/// Data is read from local Isar DB first (offline-first).
/// Uses BlocProvider to scope the WriteCubit locally,
/// and BlocBuilder with exhaustive switch for state handling.
class LearningDashboardPage extends StatelessWidget {
  const LearningDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LearningDashboardCubit>()..loadDashboard(),
      child: const _LearningDashboardView(),
    );
  }
}

/// Internal view widget — separated so BlocBuilder can
/// access the Cubit from context.
class _LearningDashboardView extends StatelessWidget {
  const _LearningDashboardView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<LearningDashboardCubit, LearningDashboardState>(
      builder: (context, state) {
        return switch (state) {
          LearningDashboardInitial() ||
          LearningDashboardLoading() => const _LoadingView(),
          LearningDashboardLoaded(
            summary: final summary,
            categorySummaries: final categories,
            questionBanks: final banks,
            recentQuizResults: final recentQuizResults,
          ) =>
            _LoadedView(
              summary: summary,
              categories: categories,
              questionBanks: banks,
              recentQuizResults: recentQuizResults,
            ),
          LearningDashboardFailure(message: final msg) => _ErrorView(
            message: msg,
            cs: cs,
            textTheme: textTheme,
          ),
        };
      },
    );
  }
}

/// Shimmer-style loading skeleton.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.withValues(alpha: 0.12);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Summary card skeleton
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 180,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 24),
          // Category skeleton
          SizedBox(
            height: 130,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (_, _) => Container(
                width: 160,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Bank card skeletons
          for (int i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              height: 120,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }
}

/// Main loaded content view.
class _LoadedView extends StatelessWidget {
  final LearningSummaryEntity summary;
  final List<CategorySummary> categories;
  final List<QuestionBankEntity> questionBanks;
  final List<RecentQuizResultEntity> recentQuizResults;

  const _LoadedView({
    required this.summary,
    required this.categories,
    required this.questionBanks,
    required this.recentQuizResults,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => context.read<LearningDashboardCubit>().loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.only(top: 20, bottom: 40),
        children: [
          // === 1. Learning Summary ===
          LearningSummaryCard(summary: summary),

          const SizedBox(height: 24),

          _SectionHeader(
            icon: Icons.history_rounded,
            title: 'Bài làm gần đây',
            subtitle: recentQuizResults.isEmpty
                ? '0 bài'
                : '${recentQuizResults.length} bài mới',
          ),
          const SizedBox(height: 8),
          RecentQuizResultsList(results: recentQuizResults),

          const SizedBox(height: 28),

          // === 2. Vocabulary Categories ===
          _SectionHeader(
            icon: Icons.category_rounded,
            title: 'Danh mục từ vựng',
            subtitle: '${categories.length} danh mục',
          ),
          const SizedBox(height: 8),
          CategoryProgressList(categories: categories),

          const SizedBox(height: 28),

          // === 3. Question Banks / Exam Sets ===
          _SectionHeader(
            icon: Icons.assignment_rounded,
            title: 'Bộ đề trắc nghiệm',
            subtitle: '${questionBanks.length} đề thi',
          ),
          const SizedBox(height: 8),

          if (questionBanks.isEmpty)
            _EmptyExamState(cs: cs, textTheme: textTheme)
          else
            ...questionBanks.map(
              (bank) => QuestionBankCard(
                bank: bank,
                onStart: () async {
                  final durationSeconds = (bank.durationMinutes ?? 5) * 60;

                  final didComplete = await context.push<bool>(
                    AppRoutes.quiz,
                    extra: {
                      'questions': const <QuizQuestionEntity>[],
                      'durationSeconds': durationSeconds,
                      'bankId': bank.backendId,
                      'bankTitle': bank.title,
                    },
                  );
                  if (didComplete == true && context.mounted) {
                    context.read<LearningDashboardCubit>().loadDashboard();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Generates sample questions for demo/testing.
  ///
  /// In production, questions are fetched from the backend
  /// via [QuizCubit.loadAndStartQuiz].
  // ignore: unused_element
  List<QuizQuestionEntity> _generateSampleQuestions(String bankTitle) {
    return [
      QuizQuestionEntity(
        id: 'q1',
        content: 'What is the correct translation of "Xin chào"?',
        options: [
          const QuizOptionEntity(id: 'q1a', text: 'Goodbye', isCorrect: false),
          const QuizOptionEntity(id: 'q1b', text: 'Hello', isCorrect: true),
          const QuizOptionEntity(
            id: 'q1c',
            text: 'Thank you',
            isCorrect: false,
          ),
          const QuizOptionEntity(id: 'q1d', text: 'Sorry', isCorrect: false),
        ],
      ),
      QuizQuestionEntity(
        id: 'q2',
        content: '"Thank you" trong tiếng Việt là gì?',
        options: [
          const QuizOptionEntity(id: 'q2a', text: 'Xin lỗi', isCorrect: false),
          const QuizOptionEntity(id: 'q2b', text: 'Tạm biệt', isCorrect: false),
          const QuizOptionEntity(id: 'q2c', text: 'Cảm ơn', isCorrect: true),
          const QuizOptionEntity(id: 'q2d', text: 'Xin chào', isCorrect: false),
        ],
      ),
      QuizQuestionEntity(
        id: 'q3',
        content: 'Choose the correct meaning of "Weather".',
        options: [
          const QuizOptionEntity(id: 'q3a', text: 'Thời tiết', isCorrect: true),
          const QuizOptionEntity(
            id: 'q3b',
            text: 'Thời gian',
            isCorrect: false,
          ),
          const QuizOptionEntity(
            id: 'q3c',
            text: 'Thời trang',
            isCorrect: false,
          ),
          const QuizOptionEntity(id: 'q3d', text: 'Thời đại', isCorrect: false),
        ],
      ),
      QuizQuestionEntity(
        id: 'q4',
        content: '"Tôi yêu bạn" means:',
        options: [
          const QuizOptionEntity(
            id: 'q4a',
            text: 'I miss you',
            isCorrect: false,
          ),
          const QuizOptionEntity(
            id: 'q4b',
            text: 'I need you',
            isCorrect: false,
          ),
          const QuizOptionEntity(
            id: 'q4c',
            text: 'I love you',
            isCorrect: true,
          ),
          const QuizOptionEntity(
            id: 'q4d',
            text: 'I know you',
            isCorrect: false,
          ),
        ],
      ),
      QuizQuestionEntity(
        id: 'q5',
        content: 'What does "Trường học" mean in English?',
        options: [
          const QuizOptionEntity(id: 'q5a', text: 'Hospital', isCorrect: false),
          const QuizOptionEntity(id: 'q5b', text: 'Library', isCorrect: false),
          const QuizOptionEntity(id: 'q5c', text: 'Market', isCorrect: false),
          const QuizOptionEntity(id: 'q5d', text: 'School', isCorrect: true),
        ],
      ),
    ];
  }
}

class RecentQuizResultsList extends StatelessWidget {
  final List<RecentQuizResultEntity> results;

  const RecentQuizResultsList({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (results.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chưa có bài làm gần đây',
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: results
          .map((result) => _RecentQuizResultCard(result: result))
          .toList(),
    );
  }
}

class _RecentQuizResultCard extends StatelessWidget {
  final RecentQuizResultEntity result;

  const _RecentQuizResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scoreColor = result.score >= 80
        ? Colors.green
        : result.score >= 60
        ? Colors.orange
        : cs.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (result.score / 100).clamp(0.0, 1.0),
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: scoreColor.withValues(alpha: 0.16),
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                ),
                Text(
                  '${result.score.round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.bankTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${result.correctAnswers}/${result.totalQuestions} đúng • ${_formatDuration(result.durationSeconds)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('dd/MM HH:mm').format(result.completedAt),
                style: textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Icon(
                result.isSynced
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_upload_outlined,
                size: 17,
                color: result.isSynced
                    ? Colors.green
                    : cs.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes == 0) {
      return '${remainingSeconds}s';
    }
    return '${minutes}p ${remainingSeconds}s';
  }
}

/// Section header with icon, title, and optional subtitle.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state when no question banks are available.
class _EmptyExamState extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme textTheme;

  const _EmptyExamState({required this.cs, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 48,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có đề thi nào',
            style: textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Đề thi sẽ được đồng bộ từ server\nkhi có kết nối mạng',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error view with retry button.
class _ErrorView extends StatelessWidget {
  final String message;
  final ColorScheme cs;
  final TextTheme textTheme;

  const _ErrorView({
    required this.message,
    required this.cs,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Không thể tải dữ liệu',
              style: textTheme.titleMedium?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  context.read<LearningDashboardCubit>().loadDashboard(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
