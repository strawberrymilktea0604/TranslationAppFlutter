# Sync Worker Implementation Plan

Mục tiêu: Đảm bảo dữ liệu học tập (flashcard, quiz attempt) không bị mất khi người dùng sử dụng offline và được đồng bộ lên server khi có mạng.
*(Lưu ý: Yêu cầu về remixed quiz đã được gỡ bỏ theo yêu cầu).*

## 1. Frontend: Sync Repository & Local Data Source
- **VocabularyLocalDataSource**:
  - Bổ sung hàm `getUnsyncedQuizResults()` để lấy dữ liệu Quiz Attempt chưa đồng bộ.
  - Bổ sung hàm `markQuizResultsSyncedAndUpdateId(Map<int, String> idMap)` để lưu `server_id` sau khi push thành công.
- **SyncPushItemModel**:
  - Thêm factory `fromQuizResultModel` để convert các model local sang DTO gửi lên API `POST /api/v1/sync/push`.
- **SyncRepositoryImpl**:
  - Trong hàm `fullSync()`, gom toàn bộ Flashcard và Quiz Attempt chưa sync vào thành một payload duy nhất để đẩy lên.
  - Xử lý response trả về: mapping `client_id` với `server_id` tương ứng cho từng resource type (`flashcard`, `quiz_attempt`).
  - Trong hàm `_pullServerChanges()`, thêm logic xử lý item `quiz_attempt` từ server trả về (nếu cần thiết, hiện tại luồng pull flashcard đã có).

## 2. Backend: Đã hỗ trợ Quiz Attempt Push
- Hệ thống backend `POST /api/v1/sync/push` đã hỗ trợ resource type `quiz_attempt` thông qua class `QuizAttemptPushPayload`. Backend đã sử dụng `QuizRepository.grade_and_save` để tính điểm và lưu. Không cần thay đổi nhiều ở Backend cho phần Quiz Attempt, chỉ cần đảm bảo Client gửi đúng format.

## 3. UI/UX: Xử lý lỗi từ chối dữ liệu (Rejected Data)
- **SyncCubit**: Cập nhật logic đọc `failedCount` từ response. Nếu có dữ liệu bị từ chối (vd: payload không hợp lệ, hoặc quiz attempt tham chiếu tới bank không tồn tại), hệ thống sẽ catch và ghi log, không làm đứng tiến trình sync của các dữ liệu hợp lệ khác. Có thể bắn một state chứa thông báo lỗi để UI hiển thị nếu cần.

## Verification Plan

### Automated/Manual Verification
- Tắt mạng (Offline mode) -> Tạo Flashcard mới -> Đổi Mastery Level -> Làm 1 bài Quiz.
- Bật mạng (Online mode) -> App tự động trigger Sync Worker qua `SyncCubit`.
- Kiểm tra lại trên server DB xem flashcard, user_quizzes có được tạo thành công không.
- Kiểm tra Isar local db xem `isSynced` đã được chuyển thành `true` chưa.
