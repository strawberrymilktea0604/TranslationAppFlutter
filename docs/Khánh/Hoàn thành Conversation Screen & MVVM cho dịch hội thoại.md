# Hoàn thành Conversation Screen & MVVM cho dịch hội thoại

## Tổng quan

Hoàn thiện màn hình dịch hội thoại (Conversation Screen) trên Flutter theo kiến trúc **MVVM** (sử dụng Cubit làm ViewModel). Hiện tại codebase đã có nền tảng tốt — Domain layer, Data layer, WebSocket datasource, Repository, và presentation layer (Cubit + UI). Tuy nhiên cần hoàn thiện các phần sau.

## Phân tích codebase hiện tại

### Đã có ✅
| Layer | Files | Status |
|-------|-------|--------|
| **Domain Entity** | [conversation_entity.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/domain/entities/conversation_entity.dart) | ✅ Đầy đủ enums, entities, events |
| **Domain Repository** | [conversation_repository.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/domain/repositories/conversation_repository.dart) | ✅ Interface đầy đủ |
| **Domain UseCase** | [connect_conversation_usecase.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/domain/usecases/connect_conversation_usecase.dart) | ⚠️ Chỉ có 1 UseCase (Connect) |
| **Data DataSource** | [conversation_remote_datasource.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/data/datasources/conversation_remote_datasource.dart) | ✅ WebSocket + auto-reconnect |
| **Data Model** | [conversation_message_model.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/data/models/conversation_message_model.dart) | ✅ JSON → Entity mapping |
| **Data Repository** | [conversation_repository_impl.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/data/repositories/conversation_repository_impl.dart) | ✅ Raw WS → domain events |
| **Presentation Cubit** | [conversation_cubit.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/bloc/conversation_cubit.dart) | ⚠️ Logic nặng, cần tách |
| **Presentation State** | [conversation_state.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/bloc/conversation_state.dart) | ✅ Sealed classes đầy đủ |
| **Presentation Page** | [conversation_page.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/pages/conversation_page.dart) | ⚠️ Cần cải thiện UX |
| **Presentation Widgets** | `message_bubble.dart`, `connection_status_indicator.dart`, `speaker_toggle.dart` | ✅ Tốt |
| **DI Registration** | [injection_container.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/injection_container.dart#L470-L496) | ✅ Đã đăng ký |

### Cần làm 🔧

1. **Tách logic từ Cubit (ViewModel)** — ConversationCubit hiện đang chứa quá nhiều logic trực tiếp (audio buffering, VAD, repository calls). Cần tách thành các UseCase riêng biệt.
2. **Thêm UseCase mới** — Thiếu UseCase cho: start session, send audio, end session, switch speaker.
3. **Cải thiện UI** — Thêm trạng thái rõ ràng hơn cho recording/processing, cải thiện error handling UX.
4. **Xử lý lỗi toàn diện** — Mic permission denied, WS disconnect, recorder failure, backend error.
5. **Auto-resume recording** — Sau khi nhận translation result, tự động bắt đầu ghi âm lại cho lượt nói tiếp theo.

---

## Proposed Changes

### 1. Domain Layer — Thêm Use Cases

> [!IMPORTANT]
> Theo Clean Architecture rules, mỗi UseCase = 1 business action. ConversationCubit hiện đang gọi trực tiếp Repository cho session/audio/speaker — cần tách thành các UseCase riêng.

#### [NEW] `start_session_usecase.dart`
`features/conversation/domain/usecases/start_session_usecase.dart`

Orchestrate session start: gọi `repository.startSession()` + `repository.sendAudioMetadata()`.

#### [NEW] `send_audio_chunk_usecase.dart`
`features/conversation/domain/usecases/send_audio_chunk_usecase.dart`

Gửi audio chunk qua repository. Tách logic validation (connection check) ra khỏi Cubit.

#### [NEW] `end_session_usecase.dart`
`features/conversation/domain/usecases/end_session_usecase.dart`

Kết thúc session: gọi `repository.endSession()`.

#### [NEW] `switch_speaker_usecase.dart`
`features/conversation/domain/usecases/switch_speaker_usecase.dart`

Chuyển đổi speaker: gọi `repository.changeSpeaker()`.

---

### 2. Presentation Layer — Refactor Cubit thành ViewModel pattern

#### [MODIFY] [conversation_cubit.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/bloc/conversation_cubit.dart)

**Rename**: `ConversationCubit` → `ConversationViewModel` (vẫn extends `Cubit<ConversationState>`, chỉ đổi tên class cho rõ MVVM intent).

**Thay đổi chính:**
- Sử dụng các UseCase mới thay vì gọi trực tiếp Repository
- Di chuyển audio buffering/chunking logic vào một helper class `AudioChunkBuffer`
- Thêm `autoResumeListening()` — sau khi nhận translation result, tự động bắt đầu recording lại
- Cải thiện error handling: phân loại lỗi rõ ràng (MicPermissionDenied, WsDisconnected, RecorderFailure, BackendError)

#### [MODIFY] [conversation_state.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/bloc/conversation_state.dart)

**Thêm trường `sessionStatus`** vào base state để UI biết lifecycle rõ ràng:
- `idle` → `recording` → `processing` → quay lại `recording`

**Thêm `errorType` enum** vào `ConversationFailure` để UI xử lý khác nhau cho từng loại lỗi:
```dart
enum ConversationErrorType {
  micPermissionDenied,
  wsDisconnected,
  recorderFailure,
  backendError,
  authRequired,
  unknown,
}
```

---

### 3. Presentation Layer — Cải thiện UI

#### [MODIFY] [conversation_page.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/pages/conversation_page.dart)

**Thay đổi chính:**
- Sử dụng `ConversationViewModel` thay vì `ConversationCubit`
- Thêm BlocListener xử lý các error type khác nhau:
  - `micPermissionDenied` → Hiện dialog hướng dẫn vào Settings
  - `wsDisconnected` → Hiện banner + nút Retry
  - `recorderFailure` → Hiện snackbar lỗi
  - `backendError` → Hiện snackbar với error code
- Thêm trạng thái hiển thị rõ ràng hơn trong bottom bar:
  - Idle → "Bắt đầu hội thoại" button
  - Recording → Animated wave indicator + "Đang nghe..."
  - Processing → Spinner + "Đang xử lý..."
  - Translation received → Auto-resume recording
- Auto-scroll khi có message mới

#### [NEW] `recording_wave_indicator.dart`
`features/conversation/presentation/widgets/recording_wave_indicator.dart`

Widget hiệu ứng sóng âm thanh responsive theo volume level, thay thế chỉ báo recording hiện tại (chỉ là dot + text).

#### [NEW] `session_status_bar.dart`
`features/conversation/presentation/widgets/session_status_bar.dart`

Widget hiển thị trạng thái session hiện tại (idle/recording/processing) với animation chuyển đổi.

---

### 4. Core Layer — Audio Buffer Helper

#### [NEW] `audio_chunk_buffer.dart`
`core/utils/audio_chunk_buffer.dart`

Tách logic audio buffering/chunking ra khỏi Cubit thành utility class:
```dart
class AudioChunkBuffer {
  final int chunkSizeBytes;
  List<int> _buffer = [];
  
  Uint8List? addAndFlush(Uint8List data);
  Uint8List? flushRemaining();
  void clear();
}
```

---

### 5. DI Registration

#### [MODIFY] [injection_container.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/injection_container.dart#L470-L496)

- Đăng ký 4 UseCase mới
- Đổi `ConversationCubit` → `ConversationViewModel`
- Inject các UseCase mới vào ViewModel

---

## Open Questions

> [!IMPORTANT]
> **MVVM vs Bloc naming**: User yêu cầu MVVM nhưng project đang dùng Cubit pattern xuyên suốt. Đề xuất: **Giữ nguyên `extends Cubit` nhưng đổi tên class thành `ConversationViewModel`** để thể hiện MVVM intent mà không phá vỡ consistency. Bạn có đồng ý không?

> [!IMPORTANT]
> **Auto-resume recording**: Sau khi nhận `final_translation` từ server, app có nên **tự động bắt đầu ghi âm lại** (continuous conversation mode) hay **đợi user nhấn nút** để ghi tiếp? Hiện tại code có logic auto-start sau `session_started` nhưng không auto-resume sau translation.

> [!NOTE]
> **Scope**: Backend WebSocket endpoint đã có sẵn (`/api/v1/ws/conversation`). Task này chỉ tập trung vào Flutter frontend — không thay đổi backend.

---

## Verification Plan

### Automated Tests
- `flutter analyze` — Kiểm tra lỗi compile
- `flutter build apk --debug` — Kiểm tra build thành công

### Manual Verification
1. Mở app → Navigate đến Conversation screen
2. Nhấn "Bắt đầu kết nối" → Kiểm tra WebSocket connected
3. Chọn ngôn ngữ → Nhấn "Bắt đầu hội thoại"
4. Nói vào microphone → Kiểm tra recording indicator
5. Im lặng > 1.5s → Kiểm tra tự động gửi audio + hiện "Đang xử lý..."
6. Nhận kết quả → Kiểm tra message bubble hiển thị đúng Speaker A/B
7. Chuyển speaker → Nói lại → Kiểm tra bubble bên phải
8. Nhấn "Kết thúc" → Kiểm tra disconnect đúng
9. Tắt microphone permission → Kiểm tra error handling
10. Tắt server → Kiểm tra reconnect + error banner
