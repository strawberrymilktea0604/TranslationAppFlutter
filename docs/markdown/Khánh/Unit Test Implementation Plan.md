# Unit Test Implementation Plan: Conversation Feature

This plan outlines the approach for setting up and writing comprehensive unit tests for the Conversation feature of the Flutter application, adhering to MVVM and Clean Architecture principles as per the provided rules.

## Background & Scope
The goal is to test the core logic of the `ConversationViewModel` (which manages the WebSocket connection, audio recording, and UI states) and the domain Use Cases (`StartSessionUseCase`, `SendAudioChunkUseCase`, `ConnectConversationUseCase`, etc.). All external dependencies (Backend APIs, Local Storage, Audio Recorders) must be mocked using `mockito` so that no real backend calls are made.

## Proposed Changes

### 1. Dependencies Update
#### [MODIFY] [pubspec.yaml](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/pubspec.yaml)
- Add `mockito`, `bloc_test`, and `flutter_test` (if missing/commented) to `dev_dependencies`.
- Ensure `build_runner` is ready for generating mock files.

---

### 2. Test Setup & Mocks
#### [NEW] [test/features/conversation/helpers/test_mocks.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/test/features/conversation/helpers/test_mocks.dart)
- Define all the `@GenerateNiceMocks` for:
  - `ConversationRepository`
  - `AuthLocalDataSource`
  - `AudioRecorderService`
  - `ConnectConversationUseCase`, `StartSessionUseCase`, `SendAudioChunkUseCase`, `SwitchSpeakerUseCase`, `EndSessionUseCase`
- Run `dart run build_runner build` to generate `test_mocks.mocks.dart`.

---

### 3. ViewModel Tests
#### [NEW] [test/features/conversation/presentation/bloc/conversation_viewmodel_test.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/test/features/conversation/presentation/bloc/conversation_viewmodel_test.dart)
- **Setup:** Initialize `ConversationViewModel` with injected mock UseCases, Repositories, and Services.
- **Tests to implement:**
  - **Start conversation (`startListening` / `connect`):** Test state emissions when mic permission is granted vs denied. Test WebSocket connection success/failure.
  - **Stop conversation (`stopListening` / `endSession`):** Verify `endUtterance()` and `disconnect()` are called on the repository.
  - **Events Handling:** Simulate WebSocket event streams (`ConversationTranslationReceived`, `ConversationErrorEvent`, `ConversationConnectionChanged`) and verify state updates.
  - **Microphone Denied:** Ensure it emits `ConversationFailure` with `ConversationErrorType.micPermissionDenied`.
  - **Error handling:** Ensure backend error events trigger appropriate error states.

---

### 4. Use Case Tests
#### [NEW] [test/features/conversation/domain/usecases/conversation_usecases_test.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/test/features/conversation/domain/usecases/conversation_usecases_test.dart)
- **Setup:** Initialize UseCases with a mock `ConversationRepository`.
- **Tests to implement:**
  - `StartSessionUseCase`: Verify it calls `repository.startSession` with correct parameters.
  - `SendAudioChunkUseCase`: Verify it calls `repository.sendAudioChunk`.
  - `EndSessionUseCase`: Verify it calls `repository.endSession`.
  - `ConnectConversationUseCase`: Verify it calls `repository.connect`.

## User Review Required

> [!IMPORTANT]
> The project currently has `mocktail` commented out in `pubspec.yaml`, but the instructional rules provide detailed instructions for `mockito` (`@flutter\rules\mockito.md`). I will proceed using **`mockito`** and `bloc_test` for the test infrastructure. Please approve if this aligns with your preferences.

## Verification Plan

### Automated Tests
- Run `flutter test test/features/conversation` to ensure all newly written unit tests pass successfully.
- Run `flutter analyze` to ensure there are no linting issues in the new test code.
