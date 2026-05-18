import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/history/data/models/history_model.dart';
import '../../features/vocabulary/data/models/vocabulary_model.dart';
import '../../features/vocabulary/data/models/vocabulary_category_model.dart';
import '../../features/vocabulary/data/models/question_bank_model.dart';
import '../../features/vocabulary/data/models/quiz_result_model.dart';

class IsarDatabase {
  late final Isar isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([
      UserModelSchema,
      HistoryModelSchema,
      VocabularyModelSchema,
      VocabularyCategoryModelSchema,
      QuestionBankModelSchema,
      QuizResultModelSchema,
    ], directory: dir.path);
  }
}
