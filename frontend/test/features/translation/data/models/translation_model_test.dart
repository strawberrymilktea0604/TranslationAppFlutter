import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/translation/data/models/translation_model.dart';

void main() {
  group('TranslationModel', () {
    test('uses detected source language instead of persisting auto', () {
      final model = TranslationModel.fromJson({
        'id': 1,
        'source_text': 'Hello',
        'translated_text': 'Xin chao',
        'source_language': 'auto',
        'detected_source_language': 'en',
        'target_language': 'vi',
        'created_at': '2026-06-03T15:42:00Z',
        'updated_at': '2026-06-03T15:42:00Z',
      });

      expect(model.sourceLanguage, 'en');
      expect(model.targetLanguage, 'vi');
    });
  });
}
