# 📋 Instruction.md — Ứng dụng Dịch thuật Đa nền tảng Tích hợp AI

> File này định nghĩa các quy tắc bắt buộc cho GitHub Copilot khi sinh code trong dự án này.
> Mọi đề xuất code phải tuân thủ đầy đủ các quy tắc bên dưới.

---

## 1. Tổng quan dự án

| Thành phần | Công nghệ |
|---|---|
| Mobile App | Flutter (iOS & Android) |
| Web Dashboard | Flutter Web |
| Backend API | FastAPI (Python) |
| Local Database | Isar DB |
| Cloud Database | PostgreSQL |
| AI Services | STT (Speech-to-Text), OCR, Translation Engine |
| DevOps | Docker, CI/CD Pipeline |

---

## 2. Kiến trúc bắt buộc — Clean Architecture

### 2.1 Quy tắc chung
- **Bắt buộc áp dụng Clean Architecture** cho toàn bộ dự án (cả Flutter lẫn FastAPI).
- Các layer **không được phép** import ngược chiều. Thứ tự phụ thuộc: `Presentation → Domain → Data`.
- Mọi business logic phải nằm trong tầng **Domain**, không được để lọt vào Presentation hoặc Data.

### 2.2 Cấu trúc thư mục Flutter

```
lib/
├── core/                   # Shared utilities, constants, extensions
│   ├── error/              # Failure classes
│   ├── network/            # Connectivity checker
│   └── utils/
├── features/
│   └── <feature_name>/     # Ví dụ: translation, vocabulary, auth
│       ├── data/
│       │   ├── datasources/    # Remote (API) & Local (Isar)
│       │   ├── models/         # DTO + toJson/fromJson + fromEntity
│       │   └── repositories/   # Implements domain repository
│       ├── domain/
│       │   ├── entities/       # Pure Dart class, không phụ thuộc framework
│       │   ├── repositories/   # Abstract interface
│       │   └── usecases/       # Một usecase = một file, extends UseCase<T, P>
│       └── presentation/
│           ├── bloc/           # Bloc/Cubit (State management)
│           ├── pages/
│           └── widgets/
└── injection_container.dart    # Dependency Injection (get_it)
```

### 2.3 Cấu trúc thư mục FastAPI

```
app/
├── api/
│   └── v1/
│       └── endpoints/      # Router cho từng module (auth, translate, sync, admin)
├── core/
│   ├── config.py           # Settings từ environment variables
│   ├── security.py         # JWT logic
│   └── dependencies.py     # FastAPI Depends()
├── models/                 # SQLAlchemy ORM models
├── schemas/                # Pydantic schemas (Request/Response DTOs)
├── services/               # Business logic layer
├── repositories/           # Database query layer (tách biệt khỏi services)
└── main.py
```

---

## 3. Quy tắc Flutter

### 3.1 State Management
- Sử dụng **Bloc/Cubit** cho mọi state management. Tuyệt đối không dùng `setState` ngoài widget cục bộ thuần UI.
- Mỗi Bloc/Cubit phải có file State và Event riêng biệt.
- Emit state `Loading` trước mọi tác vụ bất đồng bộ, sau đó emit `Success` hoặc `Failure`.

```dart
// ✅ ĐÚNG
emit(TranslationLoading());
final result = await translateUseCase(params);
result.fold(
  (failure) => emit(TranslationFailure(failure.message)),
  (data) => emit(TranslationSuccess(data)),
);

// ❌ SAI — Không xử lý lỗi, không có loading state
final result = await translateUseCase(params);
emit(TranslationSuccess(result));
```

### 3.2 Xử lý lỗi (Error Handling)
- **Bắt buộc** dùng `Either<Failure, T>` (thư viện `dartz`) cho mọi hàm trong Repository và UseCase.
- Không được dùng `try/catch` trực tiếp ở tầng Presentation.
- Mọi exception từ DataSource phải được bắt và chuyển đổi thành `Failure` ở tầng Repository.

```dart
// ✅ ĐÚNG — Repository implementation
@override
Future<Either<Failure, TranslationEntity>> translateText(TranslateParams params) async {
  try {
    final result = await remoteDataSource.translate(params);
    return Right(result.toEntity());
  } on ServerException catch (e) {
    return Left(ServerFailure(e.message));
  } on NetworkException {
    return Left(NetworkFailure());
  }
}
```

### 3.3 Offline-First (Isar DB)
- **Mọi kết quả dịch** phải được lưu vào Isar Local DB ngay lập tức, không chờ đồng bộ mạng.
- Khi đọc dữ liệu (lịch sử, từ vựng), **ưu tiên đọc từ Local DB trước**, sau đó mới cập nhật từ server.
- Mỗi bản ghi Isar phải có hai trường bắt buộc:

```dart
@collection
class TranslationModel {
  Id id = Isar.autoIncrement;
  // ... các trường khác
  bool isSynced = false;   // ← BẮT BUỘC
  bool isDeleted = false;  // ← BẮT BUỘC (soft delete)
  DateTime updatedAt = DateTime.now();
}
```

### 3.4 Performance — Flutter UI
- **Nghiêm cấm** thực hiện tác vụ nặng (query DB, gọi API) trực tiếp trong `build()`.
- Dùng `Debounce` khi gọi API dịch văn bản (thời gian tối thiểu: 500ms sau khi người dùng ngừng gõ).
- Danh sách lịch sử dài phải dùng `ListView.builder` hoặc `SliverList`, không dùng `ListView` với `children`.
- Tách widget thành các component nhỏ để tránh rebuild không cần thiết.

### 3.5 Bảo mật phía Client
- JWT Access Token và Refresh Token phải lưu bằng `flutter_secure_storage`. Tuyệt đối không lưu vào `SharedPreferences`.
- Không log token hoặc thông tin nhạy cảm ra console (kể cả trong debug mode).

---

## 4. Quy tắc FastAPI (Backend)

### 4.1 Cấu trúc API Endpoint
- Mọi response phải có cấu trúc chuẩn:

```python
# Thành công
{"status": "success", "data": {...}}

# Lỗi
{"status": "error", "code": "ERROR_CODE", "message": "Mô tả lỗi"}
```

- Sử dụng **HTTPException** với status code đúng chuẩn:
  - `401` — Sai thông tin đăng nhập / Token không hợp lệ
  - `403` — Không đủ quyền (ví dụ: endpoint chỉ dành cho Admin)
  - `404` — Resource không tồn tại
  - `422` — Dữ liệu đầu vào không hợp lệ (Pydantic tự xử lý)
  - `429` — Vượt quá giới hạn request (Rate Limiting)
  - `500` — Lỗi hệ thống nội bộ

### 4.2 Bảo mật
- Mọi endpoint trả về dữ liệu người dùng phải có `Depends(get_current_user)`.
- Mọi endpoint Admin phải có `Depends(require_admin_role)`.
- Mật khẩu **bắt buộc** hash bằng `bcrypt` (dùng `passlib`). Tuyệt đối không lưu plaintext.
- JWT phải có `exp` (expiry). Access Token: 15 phút. Refresh Token: 7 ngày.

```python
# ✅ ĐÚNG
@router.get("/users/me", dependencies=[Depends(get_current_user)])
async def get_profile(current_user: User = Depends(get_current_user)):
    ...

# ❌ SAI — Endpoint không được bảo vệ
@router.get("/users/me")
async def get_profile():
    ...
```

### 4.3 Xử lý AI Services
- Các lời gọi đến AI model (STT, OCR, Translation Engine) phải chạy bất đồng bộ (`async/await`).
- **Bắt buộc** có timeout cho mọi lời gọi external AI service (mặc định: 10 giây).
- Kết quả dịch văn bản thuần phải được **cache** (Redis hoặc in-memory) theo key `{source_lang}:{target_lang}:{text_hash}` để tránh gọi API lặp lại.

```python
# ✅ ĐÚNG — Có timeout và cache check
async def translate_text(params: TranslateParams):
    cache_key = f"{params.source}:{params.target}:{hash(params.text)}"
    cached = await cache.get(cache_key)
    if cached:
        return cached
    try:
        result = await asyncio.wait_for(
            translation_engine.translate(params),
            timeout=10.0
        )
        await cache.set(cache_key, result, ttl=3600)
        return result
    except asyncio.TimeoutError:
        raise HTTPException(status_code=503, detail="Translation service timeout")
```

### 4.4 AI-Generated Code — Quy tắc kiểm soát chất lượng
> **Cảnh báo:** Các đoạn code dưới đây do AI sinh ra, bắt buộc phải được review thủ công trước khi merge.

- Mọi **database query phức tạp** do AI sinh ra: Kiểm tra N+1 Query (phải dùng `joinedload` hoặc `selectinload` khi cần relationship).
- Mọi **tác vụ bất đồng bộ** do AI sinh ra: Kiểm tra Memory Leak (đảm bảo các task được `await` hoặc được cancel đúng cách).
- AI **chỉ được dùng** để sinh: DTOs/Schemas, boilerplate CRUD endpoints, Unit Test stubs.
- AI **không được** tự quyết định logic đồng bộ, xử lý conflict dữ liệu, hoặc các thuật toán bảo mật.

---

## 5. Database & Sync Rules (Bắt buộc)

### 5.1 PostgreSQL Schema — Quy tắc thiết kế
- Mọi bảng phải có: `id` (UUID hoặc SERIAL), `created_at` (timestamp), `updated_at` (timestamp).
- Soft delete bắt buộc: dùng cột `is_deleted BOOLEAN DEFAULT FALSE`, không dùng `DELETE` vật lý đối với dữ liệu người dùng.
- Index bắt buộc trên: `user_id`, `created_at`, `is_synced` (nếu có).

### 5.2 Chiến lược đồng bộ Offline → Online
Thuật toán đồng bộ phải tuân theo **Last-Write-Wins** dựa trên `updated_at`:

```
Khi nhận batch sync từ client:
1. Với mỗi bản ghi trong batch:
   a. Tìm bản ghi tương ứng trên Server theo ID.
   b. Nếu KHÔNG tồn tại → INSERT mới.
   c. Nếu TỒN TẠI và client.updated_at > server.updated_at → UPDATE.
   d. Nếu TỒN TẠI và client.updated_at <= server.updated_at → GIỮ NGUYÊN server, trả data mới nhất về client.
2. Trả về danh sách bản ghi đã được đồng bộ thành công kèm server_id.
3. Client cập nhật is_synced = true cho các bản ghi thành công.
```

### 5.3 Xử lý Retry khi đồng bộ thất bại
- Áp dụng **Exponential Backoff**: thử lại sau 5s, 10s, 30s, rồi dừng.
- Nếu thất bại do Token hết hạn → gọi Refresh Token trước, sau đó retry lại sync.
- Nếu Refresh Token cũng thất bại → dừng toàn bộ sync, đợi người dùng đăng nhập lại.

### 5.4 Isar DB — Quy tắc truy vấn
- Mọi query Isar phải chạy trong **Isolate** riêng biệt nếu kết quả trả về > 100 bản ghi.
- Khi xóa (từ vựng, lịch sử), phải set `isDeleted = true` + `isSynced = false`, không gọi `isar.delete()` trực tiếp.
- Không được mở nhiều hơn một Isar instance trong cùng một thời điểm.

---

## 6. Phân quyền & Use Case Mapping

| Use Case | Actor | Yêu cầu Auth | Yêu cầu Mạng |
|---|---|---|---|
| UC01 — Dịch văn bản thuần | Guest, User | Không | Có |
| UC02 — Chuyển đổi ngôn ngữ | Guest, User | Không | Không |
| UC03 — Phát âm văn bản (TTS) | Guest, User | Không | Không |
| UC04 — Quản lý tài khoản | Guest, User | Không (đăng ký/đăng nhập) | Có |
| UC05 — Dịch qua giọng nói | User | Có | Có |
| UC06 — Dịch qua hình ảnh (OCR) | User | Có | Có |
| UC07 — Lưu từ vựng | User | Có | Không (lưu local trước) |
| UC08 — Tra cứu lịch sử | User | Có | Không (offline-first) |
| UC09 — Đồng bộ dữ liệu | User (tự động) | Có | Có |
| UC10 — Quản lý người dùng | Admin | Có (role=admin) | Có |
| UC11 — Giám sát lưu lượng | Admin | Có (role=admin) | Có |

---

## 7. Quy tắc Non-Functional

### 7.1 Performance
- API dịch văn bản thuần: thời gian phản hồi **≤ 500ms** (không tính latency mạng).
- Flutter UI: không được có jank/lag khi cuộn danh sách lịch sử. Dùng `RepaintBoundary` khi cần thiết.

### 7.2 Bảo mật tổng quát
- Không hardcode API key, secret, connection string trong source code. Dùng `.env` + `python-dotenv` (backend) và `--dart-define` (Flutter).
- Mọi input từ người dùng phải được validate ở cả client (Flutter) lẫn server (Pydantic) trước khi xử lý.
- Giới hạn ký tự input dịch văn bản: **tối đa 5.000 ký tự** mỗi request.
- Giới hạn kích thước file ảnh upload: **tối đa 5MB** sau khi nén.

### 7.3 Scalability
- Backend phải được **container hóa bằng Docker**.
- Không được viết logic phụ thuộc vào trạng thái server (stateless). Mọi trạng thái session phải lưu trong JWT hoặc DB.

---

## 8. Những điều AI KHÔNG được tự ý làm

- ❌ Tự ý chọn thuật toán xử lý conflict dữ liệu khác với Last-Write-Wins đã quy định.
- ❌ Lưu token vào `SharedPreferences` hoặc biến global.
- ❌ Viết logic dịch thuật hoặc OCR trực tiếp ở tầng Presentation.
- ❌ Dùng `http.get/post` trực tiếp trong widget — phải qua UseCase → Repository → DataSource.
- ❌ Thêm thư viện mới mà không có comment giải thích lý do.
- ❌ Bỏ qua việc xử lý exception trong DataSource layer.
- ❌ Tạo endpoint mới mà không có authentication dependency tương ứng.