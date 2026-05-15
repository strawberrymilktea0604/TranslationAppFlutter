# API Quản lý Từ vựng (Vocabulary/Flashcards)

## Tổng quan

API Quản lý Từ vựng cho phép người dùng:
- **Lưu các từ/câu đã dịch** để học lại sau (Flashcards)
- **Đồng bộ giữa các thiết bị** (chỉ authenticated users)
- **Tìm kiếm và quản lý** bộ từ vựng của mình
- **Xem thống kê** về tiến độ học

### Quy tắc truy cập
- ✅ **Authenticated Users**: Có thể lưu, đồng bộ, quản lý từ vựng trên cloud
- ❌ **Guest Users**: Chỉ lưu từ vựng **cục bộ** trên thiết bị (Flutter local storage)

---

## Base URL
```
POST   /api/v1/vocabularies
GET    /api/v1/vocabularies
GET    /api/v1/vocabularies/{id}
DELETE /api/v1/vocabularies/{id}
POST   /api/v1/vocabularies/{id}/restore
POST   /api/v1/vocabularies/batch
DELETE /api/v1/vocabularies/batch/remove
GET    /api/v1/vocabularies/stats/summary
```

---

## Endpoints Chi tiết

### 1. Thêm từ vựng (POST)

**Endpoint:**
```
POST /api/v1/vocabularies
```

**Authentication:** ✅ Required (User token)

**Request Body:**
```json
{
  "translation_id": 123456789
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Translation added to vocabulary successfully",
  "data": {
    "success": true,
    "message": "Translation added to vocabulary successfully",
    "vocabulary_id": 987654321,
    "created_at": "2026-05-14T10:30:00+00:00"
  }
}
```

**Error Cases:**
```json
// 400: Translation doesn't exist or already in vocabulary
{
  "detail": "Translation 123 not found or doesn't belong to user"
}

// 400: Already in vocabulary
{
  "detail": "Translation 123456789 is already in vocabulary"
}

// 401: Unauthorized
{
  "detail": "Not authenticated"
}
```

**Python Example:**
```python
import requests

headers = {"Authorization": f"Bearer {access_token}"}

response = requests.post(
    "http://localhost:8000/api/v1/vocabularies",
    json={"translation_id": 123456789},
    headers=headers
)

print(response.json())
```

**Flutter Example:**
```dart
Future<void> addToVocabulary(int translationId) async {
  final token = await _authService.getAccessToken();
  final response = await http.post(
    Uri.parse('$baseUrl/api/v1/vocabularies'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'translation_id': translationId}),
  );

  if (response.statusCode == 201) {
    print('Added to vocabulary: ${response.body}');
  } else {
    throw Exception('Failed: ${response.body}');
  }
}
```

---

### 2. Thêm nhiều từ vựng cùng lúc (POST Batch)

**Endpoint:**
```
POST /api/v1/vocabularies/batch
```

**Authentication:** ✅ Required

**Request Body:**
```json
{
  "translation_ids": [123456789, 111111111, 222222222]
}
```

**Constraints:**
- Min: 1 item
- Max: 50 items per request

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Added 3 translations to vocabulary",
  "data": {
    "success": true,
    "message": "Added 3 translations to vocabulary",
    "count": 3,
    "vocabulary_ids": [987654321, 987654322, 987654323]
  }
}
```

**Flutter Example:**
```dart
Future<void> addMultipleToVocabulary(List<int> translationIds) async {
  final token = await _authService.getAccessToken();
  final response = await http.post(
    Uri.parse('$baseUrl/api/v1/vocabularies/batch'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'translation_ids': translationIds}),
  );

  if (response.statusCode == 201) {
    final data = jsonDecode(response.body);
    print('Added ${data['data']['count']} translations');
  }
}
```

---

### 3. Lấy danh sách từ vựng (GET)

**Endpoint:**
```
GET /api/v1/vocabularies
```

**Authentication:** ✅ Required

**Query Parameters:**
| Parameter | Type | Default | Max | Description |
|-----------|------|---------|-----|-------------|
| `page` | int | 1 | - | Trang (bắt đầu từ 1) |
| `page_size` | int | 20 | 100 | Số item trên trang |
| `search` | string | - | - | Tìm kiếm trong source/translated text |

**Response (200 OK):**
```json
{
  "items": [
    {
      "id": 987654321,
      "user_id": 12345,
      "translation_id": 123456789,
      "is_deleted": false,
      "created_at": "2026-05-14T10:30:00+00:00",
      "updated_at": "2026-05-14T10:30:00+00:00",
      "source_language": "en",
      "target_language": "vi",
      "source_text": "Hello world",
      "translated_text": "Xin chào thế giới",
      "translation_type": "text",
      "translation_created_at": "2026-05-14T09:00:00+00:00"
    }
  ],
  "total": 150,
  "page": 1,
  "page_size": 20,
  "total_pages": 8,
  "has_next": true,
  "has_prev": false
}
```

**URL Examples:**
```
# Lấy trang 1 (mặc định 20 items)
GET /api/v1/vocabularies

# Lấy trang 2 với 50 items trên trang
GET /api/v1/vocabularies?page=2&page_size=50

# Tìm kiếm "hello" trong từ vựng
GET /api/v1/vocabularies?search=hello

# Kết hợp tất cả
GET /api/v1/vocabularies?page=1&page_size=30&search=hello
```

**Flutter Example:**
```dart
Future<VocabularyListResponse> getVocabularies({
  int page = 1,
  int pageSize = 20,
  String? search,
}) async {
  final token = await _authService.getAccessToken();
  
  var url = Uri.parse('$baseUrl/api/v1/vocabularies')
    .replace(queryParameters: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (search != null) 'search': search,
    });

  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    return VocabularyListResponse.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to fetch vocabularies');
  }
}
```

---

### 4. Lấy chi tiết một từ vựng (GET)

**Endpoint:**
```
GET /api/v1/vocabularies/{vocabulary_id}
```

**Authentication:** ✅ Required

**Path Parameters:**
- `vocabulary_id` (int): ID của vocabulary entry

**Response (200 OK):**
```json
{
  "id": 987654321,
  "user_id": 12345,
  "translation_id": 123456789,
  "is_deleted": false,
  "created_at": "2026-05-14T10:30:00+00:00",
  "updated_at": "2026-05-14T10:30:00+00:00",
  "source_language": "en",
  "target_language": "vi",
  "source_text": "Good morning",
  "translated_text": "Chào buổi sáng",
  "translation_type": "text",
  "translation_created_at": "2026-05-14T09:00:00+00:00"
}
```

**Error:**
```json
// 404: Not found
{
  "detail": "Vocabulary entry 987654321 not found"
}
```

---

### 5. Xóa từ vựng (DELETE)

**Endpoint:**
```
DELETE /api/v1/vocabularies/{vocabulary_id}
```

**Authentication:** ✅ Required

**Path Parameters:**
- `vocabulary_id` (int): ID của vocabulary entry

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Vocabulary entry removed successfully",
  "data": {
    "success": true,
    "message": "Vocabulary entry removed successfully",
    "vocabulary_id": 987654321
  }
}
```

**Note:** Đây là **soft delete** - dữ liệu vẫn có trong database nhưng bị đánh dấu là xóa. Có thể restore lại nếu cần.

---

### 6. Xóa nhiều từ vựng (DELETE Batch)

**Endpoint:**
```
DELETE /api/v1/vocabularies/batch/remove
```

**Authentication:** ✅ Required

**Request Body:**
```json
{
  "translation_ids": [123456789, 111111111]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Removed 2 vocabulary entries",
  "data": {
    "success": true,
    "message": "Removed 2 vocabulary entries",
    "count": 2
  }
}
```

---

### 7. Khôi phục từ vựng đã xóa (POST)

**Endpoint:**
```
POST /api/v1/vocabularies/{vocabulary_id}/restore
```

**Authentication:** ✅ Required

**Path Parameters:**
- `vocabulary_id` (int): ID của vocabulary entry đã xóa

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Vocabulary entry restored successfully",
  "data": {
    "success": true,
    "message": "Vocabulary entry restored successfully",
    "vocabulary_id": 987654321
  }
}
```

---

### 8. Lấy thống kê từ vựng (GET)

**Endpoint:**
```
GET /api/v1/vocabularies/stats/summary
```

**Authentication:** ✅ Required

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Vocabulary statistics retrieved successfully",
  "data": {
    "total_entries": 45,
    "by_type": {
      "text": 30,
      "voice": 10,
      "image": 5
    }
  }
}
```

---

## Guest vs User: Cách triển khai trên Frontend

### Cho Guest Users (Lưu cục bộ)

```dart
// lib/services/local_vocabulary_service.dart
import 'package:sqflite/sqflite.dart';

class LocalVocabularyService {
  /// Lưu từ vựng vào local database (SQLite)
  Future<void> saveVocabularyLocally(Translation translation) async {
    final db = await openDatabase('vocabulary.db');
    
    await db.insert(
      'vocabularies',
      {
        'translation_id': translation.id,
        'source_language': translation.sourceLanguage,
        'target_language': translation.targetLanguage,
        'source_text': translation.sourceText,
        'translated_text': translation.translatedText,
        'translation_type': translation.type,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Lấy tất cả từ vựng cục bộ
  Future<List<Translation>> getLocalVocabularies() async {
    final db = await openDatabase('vocabulary.db');
    final List<Map<String, dynamic>> maps = await db.query('vocabularies');
    
    return List.generate(maps.length, (i) {
      return Translation.fromMap(maps[i]);
    });
  }

  /// Xóa từ vựng cục bộ
  Future<void> deleteLocalVocabulary(int translationId) async {
    final db = await openDatabase('vocabulary.db');
    await db.delete(
      'vocabularies',
      where: 'translation_id = ?',
      whereArgs: [translationId],
    );
  }
}
```

### Cho Authenticated Users (Cloud sync)

```dart
// lib/services/vocabulary_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class VocabularyService {
  final String baseUrl = 'http://localhost:8000/api/v1';
  final AuthService _authService;

  VocabularyService(this._authService);

  /// Thêm vào từ vựng cloud
  Future<void> addToVocabulary(int translationId) async {
    final token = await _authService.getAccessToken();
    
    final response = await http.post(
      Uri.parse('$baseUrl/vocabularies'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'translation_id': translationId}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to vocabulary: ${response.body}');
    }
  }

  /// Lấy danh sách từ vựng
  Future<List<Translation>> getVocabularies({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final token = await _authService.getAccessToken();
    
    var url = Uri.parse('$baseUrl/vocabularies').replace(
      queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (search != null) 'search': search,
      },
    );

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Translation>.from(
        (data['items'] as List).map((item) => Translation.fromJson(item))
      );
    } else {
      throw Exception('Failed to fetch vocabularies');
    }
  }

  /// Xóa từ vựng
  Future<void> removeFromVocabulary(int vocabularyId) async {
    final token = await _authService.getAccessToken();
    
    final response = await http.delete(
      Uri.parse('$baseUrl/vocabularies/$vocabularyId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove from vocabulary');
    }
  }

  /// Lấy thống kê
  Future<Map<String, dynamic>> getStats() async {
    final token = await _authService.getAccessToken();
    
    final response = await http.get(
      Uri.parse('$baseUrl/vocabularies/stats/summary'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to fetch stats');
    }
  }
}
```

---

## Nguyên tắc thiết kế

### 1. Mối quan hệ dữ liệu

```
User (1) ──→ (N) Vocabulary
             └──→ (1) Translation
                    ├─ source_text
                    ├─ translated_text
                    └─ source/target_language
```

### 2. Soft Delete

- Vocabulary entries được soft delete (đánh dấu `is_deleted = true`)
- Dữ liệu vẫn trong DB, không xóa hẳn
- Có thể restore bất kỳ lúc nào

### 3. Snowflake ID

- ID tự động tăng dựa trên Snowflake-like algorithm
- Không phụ thuộc vào database auto-increment
- Tính thống nhất giữa các hệ thống phân tán

---

## Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 201 | Created successfully | ✅ Success |
| 200 | OK | ✅ Success |
| 400 | Bad Request | Kiểm tra dữ liệu gửi |
| 401 | Unauthorized | Cần login / refresh token |
| 404 | Not Found | Item không tồn tại |
| 500 | Server Error | Liên hệ admin |

---

## Rate Limiting

API không có rate limit cụ thể cho vocabulary endpoint, nhưng:
- Tối đa **50 items** trong một batch request
- Mỗi user có thể lưu **không giới hạn** số từ vựng
- Pagination mặc định **20 items/page**, tối đa **100 items/page**

---

## Caching Strategy

Để tối ưu hiệu suất trên Flutter:

```dart
// Lưu cache danh sách từ vựng
class VocabularyCache {
  static const Duration cacheDuration = Duration(hours: 1);
  
  late Map<String, dynamic> _cache;
  late DateTime _cacheTime;

  Future<List<Translation>> getVocabularies({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid()) {
      return _cache['vocabularies'];
    }
    
    final data = await _vocabularyService.getVocabularies();
    _cache['vocabularies'] = data;
    _cacheTime = DateTime.now();
    
    return data;
  }

  bool _isCacheValid() {
    return _cache.isNotEmpty &&
        DateTime.now().difference(_cacheTime) < cacheDuration;
  }

  void invalidateCache() {
    _cache.clear();
  }
}
```

---

## Tương lai: Tính năng mở rộng

- 📊 **Learning Statistics**: Theo dõi từ nào học rồi, từ nào chưa
- 🏷️ **Tags & Categories**: Phân loại từ vựng theo chủ đề
- ⭐ **Spaced Repetition**: Nhắc học tại thời điểm tối ưu
- 🎯 **Difficulty Levels**: Đánh dấu từ khó/dễ
- 📝 **Personal Notes**: Ghi chú cá nhân cho mỗi từ

---

## Liên hệ & Support

Nếu gặp vấn đề:
1. Kiểm tra logs backend: `docker logs translation-api`
2. Xem thống kê qua `/docs` swagger
3. Kiểm tra authentication token còn hiệu lực không

