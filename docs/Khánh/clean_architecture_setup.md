# 🏗️ Cấu trúc thư mục Frontend — Clean Architecture + Bloc

## Tổng quan

Cấu trúc thư mục đã được thiết lập theo **Clean Architecture** với **Bloc/Cubit** làm State Management chính, tuân thủ đầy đủ các luật từ `copilot-instructions.md` và các rule files.

---

## Cấu trúc thư mục `lib/`

```
lib/
├── core/                              # Shared utilities, constants, extensions
│   ├── error/
│   │   ├── exceptions.dart            # ✅ ServerException, NetworkException, CacheException, AuthException, ValidationException
│   │   └── failures.dart              # ✅ ServerFailure, NetworkFailure, CacheFailure, AuthFailure, ValidationFailure (Equatable)
│   ├── network/
│   │   └── network_info.dart          # ✅ Abstract NetworkInfo interface
│   ├── usecases/
│   │   └── usecase.dart               # ✅ Base UseCase<T, P> + NoParams class
│   └── utils/
│       ├── constants.dart             # ✅ App constants (max chars, image size, debounce, token expiry)
│       ├── input_validator.dart       # ✅ Client-side validation (text, email, password, image)
│       └── typedef.dart              # ✅ ResultFuture<T>, ResultVoid, DataMap type aliases
│
├── features/
│   ├── translation/                   # UC01: Dịch văn bản thuần | UC02: Chuyển đổi ngôn ngữ | UC03: TTS
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── translation_remote_datasource.dart    # TODO
│   │   │   │   └── translation_local_datasource.dart     # TODO (Isar, offline-first)
│   │   │   ├── models/
│   │   │   │   └── translation_model.dart                # TODO (DTO + isSynced/isDeleted)
│   │   │   └── repositories/
│   │   │       └── translation_repository_impl.dart      # TODO
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── translation_entity.dart               # ✅ Pure Dart entity
│   │   │   ├── repositories/
│   │   │   │   └── translation_repository.dart           # ✅ Abstract interface
│   │   │   └── usecases/
│   │   │       └── translate_text_usecase.dart            # ✅ UseCase + Params
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── translation_cubit.dart                # ✅ Cubit with Loading→Success/Failure
│   │       │   └── translation_state.dart                # ✅ Sealed state classes
│   │       ├── pages/
│   │       │   └── translation_page.dart                 # TODO
│   │       └── widgets/
│   │           └── translation_widgets.dart              # TODO
│   │
│   ├── auth/                          # UC04: Quản lý tài khoản
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_remote_datasource.dart           # TODO
│   │   │   │   └── auth_local_datasource.dart            # TODO (flutter_secure_storage)
│   │   │   ├── models/
│   │   │   │   └── user_model.dart                       # TODO
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart             # TODO
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user_entity.dart                      # ✅ With role field
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart                  # ✅ login/register/logout/refresh
│   │   │   └── usecases/
│   │   │       ├── login_usecase.dart                    # ✅ UseCase + Params
│   │   │       └── register_usecase.dart                 # ✅ UseCase + Params
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── auth_cubit.dart                       # ✅ Global ReadCubit
│   │       │   └── auth_state.dart                       # ✅ Sealed state classes
│   │       ├── pages/
│   │       │   ├── login_page.dart                       # TODO
│   │       │   └── register_page.dart                    # TODO
│   │       └── widgets/
│   │           └── auth_widgets.dart                     # TODO
│   │
│   ├── vocabulary/                    # UC07: Lưu từ vựng (offline-first)
│   │   ├── data/ (datasources/, models/, repositories/)  # TODO scaffolded
│   │   ├── domain/
│   │   │   ├── entities/vocabulary_entity.dart           # ✅ With isSynced/isDeleted  
│   │   │   ├── repositories/vocabulary_repository.dart   # ✅ Abstract interface
│   │   │   └── usecases/save_vocabulary_usecase.dart     # TODO
│   │   └── presentation/ (bloc/, pages/, widgets/)       # TODO scaffolded
│   │
│   ├── history/                       # UC08: Tra cứu lịch sử (offline-first)
│   │   ├── data/ (datasources/, models/, repositories/)  # TODO scaffolded
│   │   ├── domain/
│   │   │   ├── entities/history_entity.dart              # ✅ With isSynced/isDeleted
│   │   │   ├── repositories/history_repository.dart      # ✅ Abstract interface
│   │   │   └── usecases/get_history_usecase.dart         # TODO
│   │   └── presentation/ (bloc/, pages/, widgets/)       # TODO scaffolded
│   │
│   ├── speech/                        # UC05: Dịch qua giọng nói (STT)
│   │   ├── data/ (datasources/, models/, repositories/)  # TODO scaffolded
│   │   ├── domain/ (entities/, repositories/, usecases/)  # TODO scaffolded
│   │   └── presentation/ (bloc/, pages/, widgets/)       # TODO scaffolded
│   │
│   ├── ocr/                           # UC06: Dịch qua hình ảnh (OCR)
│   │   ├── data/ (datasources/, models/, repositories/)  # TODO scaffolded
│   │   ├── domain/ (entities/, repositories/, usecases/)  # TODO scaffolded
│   │   └── presentation/ (bloc/, pages/, widgets/)       # TODO scaffolded
│   │
│   └── sync/                          # UC09: Đồng bộ dữ liệu (LWW + Exponential Backoff)
│       ├── data/ (datasources/, models/, repositories/)  # TODO scaffolded
│       ├── domain/ (entities/, repositories/, usecases/)  # TODO scaffolded
│       └── presentation/ (bloc/)                         # TODO scaffolded
│
├── injection_container.dart           # ✅ DI container (get_it) with registration template
├── app_config.dart                    # ✅ (existing) Environment config
├── main.dart                          # ✅ Updated with DI/Bloc hooks
├── main_dev.dart                      # ✅ (existing) Dev entry point
├── main_prod.dart                     # ✅ (existing) Prod entry point
└── main_staging.dart                  # ✅ (existing) Staging entry point
```

---

## Dependencies đã thêm vào `pubspec.yaml`

| Package | Mục đích | Liên quan luật |
|---|---|---|
| `flutter_bloc` + `bloc` | State Management (Bloc/Cubit) | copilot-instructions §3.1 |
| `equatable` | Value equality cho State/Entity | Bloc Rules |
| `dartz` | `Either<Failure, T>` pattern | copilot-instructions §3.2 |
| `get_it` | Dependency Injection | copilot-instructions §2.2 |
| `go_router` | Declarative routing | flutter-instruction.md |
| `flutter_secure_storage` | JWT token storage (NOT SharedPreferences!) | copilot-instructions §3.5 |
| `connectivity_plus` | Network connectivity check | copilot-instructions §3.3 |
| `http` | HTTP client for API calls | - |
| `json_annotation` | JSON serialization | flutter-instruction.md |
| `bloc_test` (dev) | Bloc testing | Bloc Rules §Testing |
| `mocktail` (dev) | Mocking for tests | Bloc SKILL §8 |
| `json_serializable` (dev) | Code generation | flutter-instruction.md |
| `build_runner` (dev) | Code generation runner | flutter-instruction.md |

---

## Các quy tắc kiến trúc đã tuân thủ

> [!IMPORTANT]
> **Layer Dependencies:** `Presentation → Domain → Data` (không import ngược chiều)

1. ✅ **Clean Architecture 3 layers** per feature: `data/`, `domain/`, `presentation/`
2. ✅ **Bloc/Cubit** cho State Management với sealed state classes
3. ✅ **UseCase pattern**: 1 use case = 1 file, extends `UseCase<T, P>`
4. ✅ **Either<Failure, T>** cho mọi Repository/UseCase (`dartz`)
5. ✅ **Exception → Failure** conversion ở tầng Repository
6. ✅ **emit Loading → Success/Failure** trong mọi Cubit
7. ✅ **isSynced + isDeleted** fields trong mọi Entity liên quan Isar
8. ✅ **DI container** (`get_it`) với `injection_container.dart`
9. ✅ **Global ReadCubits** ở `app.dart`, **WriteCubits** scoped per feature
10. ✅ **flutter_secure_storage** cho JWT (KHÔNG dùng SharedPreferences)

---

## Bước tiếp theo

> [!TIP]
> Ưu tiên implement theo thứ tự Use Case:

1. **UC04 - Auth**: Hoàn thiện data layer (remote + local datasource, repository impl)
2. **UC01 - Translation**: Hoàn thiện data layer + connect tới FastAPI backend
3. **UC07 - Vocabulary**: Implement Isar models + offline-first logic
4. **UC08 - History**: Implement offline-first + ListView.builder
5. **UC05 - Speech (STT)**: Integrate AI service
6. **UC06 - OCR**: Integrate AI service
7. **UC09 - Sync**: Implement Last-Write-Wins + Exponential Backoff
