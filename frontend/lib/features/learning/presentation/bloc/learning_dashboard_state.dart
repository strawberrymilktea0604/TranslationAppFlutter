import 'package:equatable/equatable.dart';

import 'package:frontend/features/learning/domain/entities/learning_summary_entity.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';
import 'package:frontend/features/learning/domain/entities/recent_quiz_result_entity.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';

/// States for the LearningDashboardCubit.
///
/// State flow:
/// - Initial → Loading → Loaded / Failure
sealed class LearningDashboardState extends Equatable {
  const LearningDashboardState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data has been loaded.
class LearningDashboardInitial extends LearningDashboardState {
  const LearningDashboardInitial();
}

/// Loading data from local Isar DB.
class LearningDashboardLoading extends LearningDashboardState {
  const LearningDashboardLoading();
}

/// Successfully loaded all dashboard data.
class LearningDashboardLoaded extends LearningDashboardState {
  /// Aggregated learning progress summary.
  final LearningSummaryEntity summary;

  /// Category-level vocabulary summaries.
  final List<CategorySummary> categorySummaries;

  /// Available exam sets.
  final List<QuestionBankEntity> questionBanks;

  /// Recent quiz attempts, newest first.
  final List<RecentQuizResultEntity> recentQuizResults;

  const LearningDashboardLoaded({
    required this.summary,
    required this.categorySummaries,
    required this.questionBanks,
    required this.recentQuizResults,
  });

  @override
  List<Object?> get props => [
    summary,
    categorySummaries,
    questionBanks,
    recentQuizResults,
  ];
}

/// An error occurred while loading dashboard data.
class LearningDashboardFailure extends LearningDashboardState {
  final String message;

  const LearningDashboardFailure(this.message);

  @override
  List<Object?> get props => [message];
}
