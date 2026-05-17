import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/learning/domain/entities/learning_summary_entity.dart';
import 'package:frontend/features/learning/domain/entities/question_bank_entity.dart';
import 'package:frontend/features/learning/domain/usecases/get_learning_summary_usecase.dart';
import 'package:frontend/features/learning/domain/usecases/get_question_banks_usecase.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';
import 'package:frontend/features/vocabulary/domain/usecases/get_vocabulary_list_usecase.dart'
    show GetCategorySummariesUseCase;
import 'learning_dashboard_state.dart';

/// Manages the Learning Dashboard state.
///
/// Flow: UI → Cubit → UseCase → Repository → DataSource (Isar).
///
/// Loads three pieces of data in parallel:
/// 1. Learning summary (total words, learned, quizzes, avg score)
/// 2. Category summaries (per-category word count + progress)
/// 3. Question banks (available exam sets)
class LearningDashboardCubit extends Cubit<LearningDashboardState> {
  final GetLearningSummaryUseCase _getLearningSummaryUseCase;
  final GetQuestionBanksUseCase _getQuestionBanksUseCase;
  final GetCategorySummariesUseCase _getCategorySummariesUseCase;

  LearningDashboardCubit({
    required GetLearningSummaryUseCase getLearningSummaryUseCase,
    required GetQuestionBanksUseCase getQuestionBanksUseCase,
    required GetCategorySummariesUseCase getCategorySummariesUseCase,
  })  : _getLearningSummaryUseCase = getLearningSummaryUseCase,
        _getQuestionBanksUseCase = getQuestionBanksUseCase,
        _getCategorySummariesUseCase = getCategorySummariesUseCase,
        super(const LearningDashboardInitial());

  /// Loads all dashboard data.
  ///
  /// Emits: [LearningDashboardLoading] →
  ///   [LearningDashboardLoaded] or [LearningDashboardFailure].
  Future<void> loadDashboard() async {
    emit(const LearningDashboardLoading());

    // Fetch summary.
    final summaryResult = await _getLearningSummaryUseCase(
      const NoParams(),
    );

    LearningSummaryEntity? summary;
    final summaryFailure = summaryResult.fold(
      (failure) => failure.message,
      (data) {
        summary = data;
        return null;
      },
    );
    if (summaryFailure != null) {
      emit(LearningDashboardFailure(summaryFailure));
      return;
    }

    // Fetch question banks.
    final banksResult = await _getQuestionBanksUseCase(
      const NoParams(),
    );

    List<QuestionBankEntity>? banks;
    final banksFailure = banksResult.fold(
      (failure) => failure.message,
      (data) {
        banks = data;
        return null;
      },
    );
    if (banksFailure != null) {
      emit(LearningDashboardFailure(banksFailure));
      return;
    }

    // Fetch category summaries.
    final categoriesResult = await _getCategorySummariesUseCase(
      const NoParams(),
    );

    List<CategorySummary>? categories;
    final categoriesFailure = categoriesResult.fold(
      (failure) => failure.message,
      (data) {
        categories = data;
        return null;
      },
    );
    if (categoriesFailure != null) {
      emit(LearningDashboardFailure(categoriesFailure));
      return;
    }

    emit(LearningDashboardLoaded(
      summary: summary!,
      categorySummaries: categories!,
      questionBanks: banks!,
    ));
  }
}
