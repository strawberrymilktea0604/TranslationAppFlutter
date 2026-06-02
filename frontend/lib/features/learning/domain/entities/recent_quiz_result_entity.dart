import 'package:equatable/equatable.dart';

class RecentQuizResultEntity extends Equatable {
  final int localId;
  final String backendId;
  final String bankId;
  final String bankTitle;
  final int totalQuestions;
  final int correctAnswers;
  final double score;
  final int durationSeconds;
  final String status;
  final DateTime completedAt;
  final bool isSynced;

  const RecentQuizResultEntity({
    required this.localId,
    required this.backendId,
    required this.bankId,
    required this.bankTitle,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.durationSeconds,
    required this.status,
    required this.completedAt,
    required this.isSynced,
  });

  @override
  List<Object?> get props => [
    localId,
    backendId,
    bankId,
    bankTitle,
    totalQuestions,
    correctAnswers,
    score,
    durationSeconds,
    status,
    completedAt,
    isSynced,
  ];
}
