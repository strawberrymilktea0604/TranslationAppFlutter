# Xây dựng Conversation Screen — Real-time Voice Translation

Tạo màn hình hội thoại phiên dịch real-time giữa hai người nói (Speaker A / Speaker B) sử dụng WebSocket, tuân thủ Clean Architecture + BLoC pattern có sẵn trong dự án.

## User Review Required

> [!IMPORTANT]
> Backend đã có sẵn WebSocket endpoint tại `/api/v1/ws/conversation` với protocol đầy đủ: `session_start` → `audio_metadata` → binary PCM chunks → `end_utterance` → `translation_result` → `session_end`. Feature này sẽ tích hợp trực tiếp với backend protocol này.

> [!WARNING]
> Task này chỉ xây dựng **UI layer + BLoC + Domain + Data** cho Conversation Screen. Chưa tích hợp thực tế với microphone recording (sẽ chuẩn bị UI states cho trạng thái "đang nghe" và "đang xử lý" nhưng chưa gọi `AudioRecorderService`). Audio recording integration sẽ là task tiếp theo.

## Open Questions

> [!IMPORTANT]
> **Q1**: Conversation screen có yêu cầu authentication (chỉ authenticated users) hay cho phép cả guest? Backend WS endpoint yêu cầu JWT token, nên mình sẽ mặc định là **chỉ authenticated users**.

> [!IMPORTANT]
> **Q2**: Có muốn hiển thị WebSocket connection status dạng `Chip` ở AppBar hay dạng banner ở dưới? Mình sẽ dùng **Chip indicator trên AppBar** (nhỏ gọn, giống pattern các ứng dụng chat hiện đại).

---

## Proposed Changes

### Feature: Conversation (New Feature Module)

Tạo feature module mới `features/conversation/` theo đúng cấu trúc Clean Architecture giống các feature hiện có (`speech/`, `translation/`).

```
features/conversation/
├── data/
│   ├── datasources/
│   │   └── conversation_remote_datasource.dart    [NEW]
│   ├── models/
│   │   └── conversation_message_model.dart        [NEW]
│   └── repositories/
│       └── conversation_repository_impl.dart      [NEW]
├── domain/
│   ├── entities/
│   │   └── conversation_entity.dart               [NEW]
│   ├── repositories/
│   │   └── conversation_repository.dart           [NEW]
│   └── usecases/
│       └── connect_conversation_usecase.dart       [NEW]
└── presentation/
    ├── bloc/
    │   ├── conversation_cubit.dart                 [NEW]
    │   └── conversation_state.dart                 [NEW]
    ├── pages/
    │   └── conversation_page.dart                  [NEW]
    └── widgets/
        ├── conversation_widgets.dart               [NEW]
        ├── message_bubble.dart                     [NEW]
        ├── speaker_toggle.dart                     [NEW]
        └── connection_status_indicator.dart        [NEW]
```

---

### Domain Layer

#### [NEW] [conversation_entity.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/domain/entities/conversation_entity.dart)

Equatable entity cho conversation message:
- `id` (String — UUID)
- `speaker` (enum `ConversationSpeaker { speakerA, speakerB }`)
- `sourceText` (String — text nhận diện từ STT)
- `translatedText` (String — text đã dịch)
- `sourceLanguage` / `targetLanguage`
- `timestamp` (DateTime)
- `isCached` (bool)

Enum `WebSocketConnectionStatus { disconnected, connecting, connected, reconnecting, error }`

Enum `ConversationSessionStatus { idle, recording, processing, ended }`

#### [NEW] [conversation_repository.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/domain/repositories/conversation_repository.dart)

Abstract repository interface:
- `Stream<ConversationEvent> connect(String accessToken)` — connects and returns event stream
- `void startSession({srcLang, tgtLang, speaker})` — sends `session_start`
- `void sendAudioMetadata({sampleRate, audioFormat, speaker, srcLang, tgtLang})` — sends `audio_metadata`
- `void sendAudioChunk(Uint8List chunk)` — sends binary PCM data
- `void endUtterance()` — signals end of speech
- `void changeSpeaker(speaker)` — sends `speaker_changed`
- `void endSession()` — sends `session_end`
- `void disconnect()` — closes WebSocket
- `WebSocketConnectionStatus get connectionStatus`

#### [NEW] [connect_conversation_usecase.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/domain/usecases/connect_conversation_usecase.dart)

UseCase orchestrating the conversation connection:
- Lấy access token từ `AuthLocalDataSource`
- Gọi `repository.connect(token)`
- Trả về `Either<Failure, Stream<ConversationEvent>>`

---

### Data Layer

#### [NEW] [conversation_message_model.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/data/models/conversation_message_model.dart)

Data model mapping JSON → Entity. Parses backend `translation_result` event JSON.

#### [NEW] [conversation_remote_datasource.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/data/datasources/conversation_remote_datasource.dart)

WebSocket datasource wrapping `web_socket_channel` package (đã có trong pubspec.yaml):
- `connect(String wsUrl, String token)` → opens WebSocket to `ws://<host>/api/v1/ws/conversation?token=<token>`
- `sendJson(Map<String, dynamic>)` → sends text frame
- `sendBytes(Uint8List)` → sends binary frame
- `Stream<dynamic> get messageStream`
- `disconnect()`
- Keepalive ping every 25s (giống `RealtimeSyncService` pattern)
- Auto-reconnect logic

#### [NEW] [conversation_repository_impl.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/data/repositories/conversation_repository_impl.dart)

Implements `ConversationRepository`. Maps raw WS messages to domain events:
- `session_started` → `ConversationSessionStarted`
- `translation_result` → `ConversationTranslationReceived`
- `error` → `ConversationError`
- `audio_metadata_ack` → `ConversationMetadataAcknowledged`

---

### Presentation Layer — BLoC (Cubit)

#### [NEW] [conversation_state.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/bloc/conversation_state.dart)

Sealed class states (theo Bloc rules):
- `ConversationInitial` — chưa bắt đầu
- `ConversationConnecting` — đang kết nối WebSocket
- `ConversationConnected` — kết nối thành công, idle
- `ConversationRecording` — đang nghe (speaker đang nói)
- `ConversationProcessing` — đang xử lý STT + translate
- `ConversationDisconnected` — mất kết nối
- `ConversationError` — lỗi

Shared properties trong sealed base: `messages` (List), `currentSpeaker`, `connectionStatus`, `srcLang`, `tgtLang`

#### [NEW] [conversation_cubit.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/bloc/conversation_cubit.dart)

ConversationCubit methods:
- `connect()` → connect WebSocket, emit Connecting → Connected
- `startSession(srcLang, tgtLang)` → send session_start event
- `startListening()` → emit Recording state (UI preparation)
- `stopListening()` → send end_utterance, emit Processing
- `switchSpeaker()` → toggle speaker, send speaker_changed
- `endSession()` → send session_end, clear messages
- `disconnect()` → close WebSocket
- Internal: listen to WS stream, update messages list khi nhận `translation_result`

---

### Presentation Layer — Pages & Widgets

#### [NEW] [conversation_page.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/pages/conversation_page.dart)

Main page layout:
- **AppBar**: Tiêu đề "Phiên dịch hội thoại" + `ConnectionStatusIndicator` chip
- **Body**: `ListView` of `MessageBubble` widgets
  - Speaker A messages aligned left (blue gradient)
  - Speaker B messages aligned right (teal gradient)
  - Mỗi bubble hiển thị: source text, translated text, timestamp
- **Bottom bar**:
  - `SpeakerToggle` widget — hiển thị ai đang nói (A/B), nhấn để switch
  - Nút microphone lớn (hold-to-talk hoặc tap-to-start)
  - Nút dừng cuộc hội thoại (end session)
- **States**:
  - Idle: "Nhấn mic để bắt đầu nói"
  - Recording: ripple animation quanh nút mic + "Đang nghe..."
  - Processing: loading spinner + "Đang xử lý..."
  - Disconnected: banner cảnh báo + nút retry

#### [NEW] [message_bubble.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/widgets/message_bubble.dart)

Chat bubble widget:
- Hiển thị speaker label ("Speaker A" / "Speaker B")
- Source text (nhỏ, italic)
- Translated text (chữ lớn, bold)
- Timestamp
- Animated entry (slide + fade)
- Màu sắc khác nhau cho 2 speakers (gradient background)

#### [NEW] [speaker_toggle.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/widgets/speaker_toggle.dart)

Toggle widget chọn speaker hiện tại:
- 2 nút: Speaker A / Speaker B
- Highlight active speaker
- Animation khi chuyển

#### [NEW] [connection_status_indicator.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/conversation/presentation/widgets/connection_status_indicator.dart)

Chip/badge hiển thị trạng thái WebSocket:
- 🟢 Connected
- 🟡 Connecting/Reconnecting
- 🔴 Disconnected/Error
- Animated dot pulse

---

### Integration — Router & DI

#### [MODIFY] [app_router.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/core/router/app_router.dart)

- Thêm route `conversation = '/conversation'` vào `AppRoutes`
- Thêm `GoRoute` cho `ConversationPage` với slide-up transition
- Thêm vào danh sách public pages (vì cần auth, sẽ guard ở Cubit level)

#### [MODIFY] [injection_container.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/injection_container.dart)

- Register `ConversationRemoteDataSource` (lazySingleton)
- Register `ConversationRepository` → `ConversationRepositoryImpl` (lazySingleton)
- Register `ConnectConversationUseCase` (lazySingleton)
- Register `ConversationCubit` (factory — new instance per screen)

---

## Verification Plan

### Automated Tests
- `flutter analyze` — đảm bảo không có lỗi static analysis
- Verify build thành công: `flutter build apk --debug` (dry run)

### Manual Verification
- Navigate đến Conversation screen thông qua route `/conversation`
- Kiểm tra UI hiển thị đúng các trạng thái (initial, connecting, connected, recording, processing, disconnected)
- Kiểm tra message bubbles render đúng cho Speaker A / Speaker B
- Kiểm tra speaker toggle hoạt động
- Kiểm tra connection status indicator thay đổi theo state
