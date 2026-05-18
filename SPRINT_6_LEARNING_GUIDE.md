# Sprint 6 Learning Guide

Generated: May 19, 2026

## Muc tieu Sprint 6

Sprint 6 tap trung hoan thien learning flow:

- Flashcard CRUD va tien do hoc tu vung.
- Question bank va cau hoi quiz.
- Quiz submission va luu ket qua.
- Mobile Learning Dashboard, Flashcard screen, Quiz Engine UI.
- Countdown timer va auto-submit.
- Offline-first data bang Isar.
- PostgreSQL backup tu dong.
- Redis cache cho quiz mac dinh.
- QA luong hoc tap chinh.

## Trang thai hien tai

| Hang muc | Trang thai | Ghi chu |
|---|---:|---|
| Database schema flashcard/question bank/question/quiz attempt | Done | Co `vocabularies`, `question_banks`, `questions`, `user_quizzes` trong model va migration. |
| Backend API CRUD flashcard | Done | `/api/v1/vocabularies` co create/list/detail/patch/delete/batch/restore. |
| Backend API lay question bank va cau hoi | Done | `/api/v1/learning/banks`, `/banks/{id}`, `/questions`, `/start`. |
| Backend API submit quiz va luu ket qua | Done | `/api/v1/learning/banks/{id}/submit`, backend tests pass. |
| Mobile Learning Dashboard | Done | `LearningDashboardPage` da co UI va cubit. |
| Mobile flashcard screen | Done | `FlashcardPage` da co flip card, next/previous, TTS. |
| Mobile Quiz Engine UI | Done | `QuizPage` da co cau hoi, options, progress, result sheet. |
| Quiz countdown timer | Done | `QuizCubit` dung `Stream.periodic`. |
| Quiz auto-submit khi het gio | Done | Timer ve 0 se goi `submitQuiz()`. |
| Learning data luu trong Isar offline | Partial | Co Isar schema cho vocabulary, question bank, quiz result; quiz submit mobile chua ghi local result ro rang. |
| PostgreSQL backup tu dong | Done | `BackupScheduler` chay daily 2:00 AM. |
| Redis cache cho default quizzes | Done | `/banks` va `/start` co Redis cache. |
| QA luong hoc tap chinh | Partial | Backend learning tests pass; chua co UI/e2e test mobile. |
| Khong con loi nghiem trong flashcard/quiz | Partial | Backend da pass; mobile quiz remote endpoint va data flow can canh lai. |

## Backend

### Database schema

File chinh:

- `backend/app/models/translation.py`: `Vocabulary`, `VocabularyCategory`.
- `backend/app/models/learning.py`: `QuestionBank`, `Question`, `UserQuiz`.
- `backend/alembic/versions/a4f54dfde5de_init_database.py`: migration tao bang.

Bang lien quan:

| Table | Vai tro |
|---|---|
| `vocabularies` | Flashcard/vocabulary cua user, co `mastery_level`, `last_tested_at`, soft delete. |
| `vocabulary_categories` | Nhom flashcard. |
| `question_banks` | Bo de quiz, co `duration_minutes`. |
| `questions` | Cau hoi cua bank, `choices` dang JSONB, `correct_answer` chi dung server/admin. |
| `user_quizzes` | Ket qua attempt, score, time spent, total/correct answers, status. |

### Chay migration

```powershell
cd D:\TranslationAppFlutter\backend
alembic upgrade head
```

### Start backend local

```powershell
cd D:\TranslationAppFlutter\backend
uvicorn app.main:app --reload
```

Health check:

```powershell
curl http://127.0.0.1:8000/api/v1/health
```

Swagger:

```text
http://127.0.0.1:8000/docs
```

### Learning API

Tat ca endpoint learning can auth token.

| Method | Endpoint | Muc dich |
|---|---|---|
| GET | `/api/v1/learning/banks` | Lay danh sach question bank. |
| GET | `/api/v1/learning/banks/{bank_id}` | Lay bank detail kem cau hoi public, khong co `correct_answer`. |
| GET | `/api/v1/learning/banks/{bank_id}/questions?page=1&page_size=20` | Lay cau hoi co phan trang, khong co `correct_answer`. |
| GET | `/api/v1/learning/banks/{bank_id}/start` | Start quiz, lay metadata va toan bo active questions. |
| POST | `/api/v1/learning/banks/{bank_id}/submit` | Cham diem, luu `user_quizzes`, tra breakdown. |
| GET | `/api/v1/learning/history` | Lay lich su quiz cua user. |
| GET | `/api/v1/learning/admin/banks/{bank_id}` | Admin/internal detail co `correct_answer`. Can them RBAC truoc production public. |

Submit quiz example:

```json
{
  "answers": [
    {"question_id": 101, "selected_answer": "A"},
    {"question_id": 102, "selected_answer": "C"}
  ],
  "time_spent_seconds": 45
}
```

Response chinh:

```json
{
  "quiz_id": 55,
  "bank_id": 10,
  "score": 50.0,
  "total_questions": 2,
  "correct_count": 1,
  "correct_answers": 1,
  "completion_time_seconds": 45,
  "time_spent_seconds": 45,
  "status": "completed",
  "results": []
}
```

### Flashcard API

| Method | Endpoint | Muc dich |
|---|---|---|
| POST | `/api/v1/vocabularies` | Add translation vao flashcard/vocabulary. |
| POST | `/api/v1/vocabularies/batch` | Add nhieu translations. |
| GET | `/api/v1/vocabularies` | List vocabulary cua user. |
| GET | `/api/v1/vocabularies/{vocabulary_id}` | Lay detail mot flashcard. |
| PATCH | `/api/v1/vocabularies/{vocabulary_id}` | Update learning progress: `mastery_level`, `last_tested_at`. |
| DELETE | `/api/v1/vocabularies/{vocabulary_id}` | Soft delete. |
| DELETE | `/api/v1/vocabularies/batch/remove` | Soft delete nhieu items. |
| POST | `/api/v1/vocabularies/{vocabulary_id}/restore` | Restore deleted item. |
| GET | `/api/v1/vocabularies/stats/summary` | Thong ke vocabulary. |

## Mobile

### Man hinh Learning Dashboard

File chinh:

- `frontend/lib/features/learning/presentation/pages/learning_dashboard_page.dart`
- `frontend/lib/features/learning/presentation/bloc/learning_dashboard_cubit.dart`
- `frontend/lib/features/learning/data/repositories/learning_repository_impl.dart`

Chuc nang:

- Doc summary tu local Isar.
- Hien thi category progress.
- Hien thi danh sach question banks.
- Pull-to-refresh qua `LearningDashboardCubit.loadDashboard()`.

Can luu y:

- Dashboard hien dang tao sample questions khi bam start quiz.
- De dung backend that, can wire flow qua `QuizCubit.loadAndStartQuiz()` hoac doc questions tu `QuestionBankModel.questions`.

### Flashcard screen

File chinh:

- `frontend/lib/features/vocabulary/presentation/pages/flashcard_page.dart`

Chuc nang:

- Flip card de xem nghia.
- Next/previous.
- TTS cho mat tu goc.

### Quiz Engine UI

File chinh:

- `frontend/lib/features/learning/presentation/pages/quiz_page.dart`
- `frontend/lib/features/learning/presentation/bloc/quiz_cubit.dart`
- `frontend/lib/features/learning/presentation/widgets/quiz_timer_widget.dart`
- `frontend/lib/features/learning/presentation/widgets/quiz_option_tile.dart`
- `frontend/lib/features/learning/presentation/widgets/quiz_result_sheet.dart`

Chuc nang:

- Countdown timer.
- Warning/critical state theo thoi gian con lai.
- Auto-submit khi het gio.
- Result bottom sheet sau khi submit.

Gap can xu ly tiep:

- `frontend/lib/features/learning/data/datasources/quiz_remote_datasource.dart` dang goi `/api/v1/quiz/...`, trong khi backend dung `/api/v1/learning/...`.
- Payload mobile submit hien dang gui `bank_id`, `correct_count`, `selected_answers`; backend can `answers` va `time_spent_seconds`.
- `QuizRepositoryImpl.submitResult()` tra success offline nhung chua thay luu `QuizResultModel` vao Isar trong submit path.

## Offline Data voi Isar

Isar database:

- `frontend/lib/core/database/isar_database.dart`

Collections da dang ky:

- `VocabularyModelSchema`
- `VocabularyCategoryModelSchema`
- `QuestionBankModelSchema`
- `QuizResultModelSchema`

Local datasource:

- `frontend/lib/features/vocabulary/data/datasources/vocabulary_local_datasource.dart`

Local methods quan trong:

- `getAllBanks()`
- `saveBank()`
- `saveAllBanks()`
- `getQuizResults()`
- `saveQuizResult()`
- `getUnsyncedQuizResults()`
- `markQuizResultsSynced()`

De tick full offline learning, can dam bao:

1. Sync tu backend ve Isar cho question banks va questions.
2. Quiz start doc duoc bank/questions tu Isar khi offline.
3. Sau submit, ket qua duoc luu vao `QuizResultModel`.
4. Khi online lai, unsynced quiz results duoc upload len backend.

## Backup va Redis Cache

### PostgreSQL backup

Files:

- `backend/app/services/backup_service.py`
- `backend/app/main.py`
- `docker-compose.yml`

Behavior:

- Backup service dung `pg_dump`.
- Scheduler chay daily luc 2:00 AM.
- Giu 7 backup gan nhat.
- Backup dir default: `/backups/database`.

Manual backup endpoint:

```powershell
curl -X POST http://127.0.0.1:8000/api/v1/management/backups/create `
  -H "Authorization: Bearer $TOKEN"
```

### Redis cache cho quiz

Files:

- `backend/app/services/static_cache_service.py`
- `backend/app/core/dependencies.py`
- `backend/app/api/v1/endpoints/learning.py`

Cached endpoints:

- `GET /api/v1/learning/banks`
- `GET /api/v1/learning/banks/{bank_id}/start`

Cache prefixes:

- `quiz_banks:`
- `quiz_start:`

Redis trong Docker:

```powershell
docker-compose exec redis redis-cli
KEYS "quiz_*"
```

## Seed du lieu learning

Seed script:

- `backend/scripts/seed_learning_data.py`

Run:

```powershell
cd D:\TranslationAppFlutter\backend
python scripts\seed_learning_data.py
```

Script nay tao sample question banks va questions de test dashboard/quiz.

## QA Checklist

### Backend QA

Run learning tests:

```powershell
cd D:\TranslationAppFlutter
.\.venv\Scripts\python.exe -m pytest backend\tests\test_learning_quiz_submission.py backend\tests\test_learning_banks_and_questions.py
```

Expected:

```text
30 passed
```

Can test thu cong:

1. Login lay token.
2. `GET /api/v1/learning/banks`.
3. `GET /api/v1/learning/banks/{id}/start`.
4. Dam bao public response khong co `correct_answer`.
5. Submit quiz dung `answers` va `time_spent_seconds`.
6. Kiem tra `GET /api/v1/learning/history`.
7. Submit qua time limit va xac nhan backend reject 400.

### Mobile QA

Checklist mobile:

1. Mo tab Learning.
2. Dashboard load duoc summary, categories, banks.
3. Bam start quiz.
4. Quiz hien cau hoi, options, progress, timer.
5. Chon dap an, next/previous hoat dong.
6. De timer ve 0 va xac nhan auto-submit.
7. Submit manual va xac nhan result sheet.
8. Tat mang, mo lai Learning Dashboard va xac nhan data local van hien.
9. Lam quiz offline va xac nhan ket qua duoc luu local.
10. Bat mang lai va xac nhan sync result len backend.

## Definition of Done

Sprint 6 chi nen close khi:

1. Backend learning tests pass.
2. Migration da apply tren environment muc tieu.
3. Seed/default question banks co data.
4. Redis cache endpoint learning hoat dong va khong lam bien dang response.
5. Backup scheduler khoi dong thanh cong trong backend logs.
6. Mobile dashboard, flashcard, quiz UI chay duoc tren device/emulator.
7. Mobile quiz dung endpoint backend chinh xac: `/api/v1/learning/...`.
8. Quiz result duoc luu local Isar truoc khi sync.
9. QA da test happy path va timeout path.
10. Khong con blocker anh huong flashcard hoac quiz.

## Known Gaps Can Xu Ly

### 1. Mobile quiz remote endpoint mismatch

Hien tai:

```text
GET  /api/v1/quiz/{bankId}/questions
POST /api/v1/quiz/submit
```

Backend thuc te:

```text
GET  /api/v1/learning/banks/{bank_id}/start
POST /api/v1/learning/banks/{bank_id}/submit
```

Can update `QuizRemoteDataSourceImpl`.

### 2. Mobile submit payload mismatch

Backend can:

```json
{
  "answers": [
    {"question_id": 101, "selected_answer": "A"}
  ],
  "time_spent_seconds": 45
}
```

Can map `selectedAnswers` tu UI thanh list `answers`.

### 3. Local quiz result persistence

Can dam bao submit path goi:

```dart
VocabularyLocalDataSource.saveQuizResult(...)
```

truoc hoac sau remote submit, de offline-first that su hoat dong.

### 4. Dashboard dang dung sample questions

Can thay `_generateSampleQuestions()` bang:

- Load questions tu local `QuestionBankModel.questions`; hoac
- Goi `QuizCubit.loadAndStartQuiz()` de fetch tu backend khi online.

## File Reference

Backend:

- `backend/app/models/learning.py`
- `backend/app/models/translation.py`
- `backend/app/api/v1/endpoints/learning.py`
- `backend/app/api/v1/endpoints/vocabulary.py`
- `backend/app/repositories/quiz_repository.py`
- `backend/app/services/static_cache_service.py`
- `backend/app/services/backup_service.py`
- `backend/tests/test_learning_quiz_submission.py`
- `backend/tests/test_learning_banks_and_questions.py`

Frontend:

- `frontend/lib/core/database/isar_database.dart`
- `frontend/lib/features/learning/presentation/pages/learning_dashboard_page.dart`
- `frontend/lib/features/vocabulary/presentation/pages/flashcard_page.dart`
- `frontend/lib/features/learning/presentation/pages/quiz_page.dart`
- `frontend/lib/features/learning/presentation/bloc/quiz_cubit.dart`
- `frontend/lib/features/learning/data/datasources/quiz_remote_datasource.dart`
- `frontend/lib/features/vocabulary/data/datasources/vocabulary_local_datasource.dart`
- `frontend/lib/features/vocabulary/data/models/question_bank_model.dart`
- `frontend/lib/features/vocabulary/data/models/quiz_result_model.dart`
