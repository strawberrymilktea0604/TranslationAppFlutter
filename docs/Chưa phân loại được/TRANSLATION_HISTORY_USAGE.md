# Hướng dẫn Sử dụng API Quản lý Lịch sử Dịch thuật

## 🚀 Quick Start

### 1. Khởi động Backend Server
```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

### 2. Truy cập API Documentation
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

---

## 📖 API Endpoints Summary

| Method | Endpoint | Mục đích |
|--------|----------|---------|
| POST | `/api/v1/translations` | Dịch text và lưu lịch sử |
| GET | `/api/v1/translations/{id}` | Lấy chi tiết một translation |
| GET | `/api/v1/translations/history` | Lấy lịch sử (phân trang) |
| GET | `/api/v1/translations/search` | Tìm kiếm translations |
| GET | `/api/v1/translations/filter` | Lọc theo ngôn ngữ/loại dịch |
| DELETE | `/api/v1/translations/{id}` | Xóa một translation |
| POST | `/api/v1/translations/bulk-delete` | Xóa hàng loạt |
| GET | `/api/v1/translations/cache/stats` | Cache statistics |
| POST | `/api/v1/translations/cache/clear` | Xóa cache |

---

## 🔍 Chi tiết Các Endpoints

### 1️⃣ Lấy Lịch sử Dịch thuật (Phân trang)

**Endpoint:** `GET /api/v1/translations/history`

**Query Parameters:**
- `skip` (int, optional): Records to skip, default: 0
- `limit` (int, optional): Records per page, default: 50, max: 100

**cURL Example:**
```bash
curl -X GET "http://localhost:8000/api/v1/translations/history?skip=0&limit=20" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Python Example:**
```python
import requests

token = "YOUR_ACCESS_TOKEN"
headers = {"Authorization": f"Bearer {token}"}

# Get first 20 translations
response = requests.get(
    "http://localhost:8000/api/v1/translations/history",
    params={"skip": 0, "limit": 20},
    headers=headers
)

data = response.json()
print(f"Total: {data['total']}")
print(f"Retrieved: {len(data['data'])}")

for translation in data['data']:
    print(f"  {translation['source_text']} → {translation['translated_text']}")
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1001,
      "source_text": "Hello",
      "translated_text": "Xin chào",
      "source_language": "en",
      "target_language": "vi",
      "translation_type": "text",
      "is_cached": false,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "total": 1500
}
```

---

### 2️⃣ Tìm kiếm Translations

**Endpoint:** `GET /api/v1/translations/search`

**Query Parameters:**
- `q` (string, required): Search text (1-500 chars)
- `skip` (int, optional): Records to skip, default: 0
- `limit` (int, optional): Records per page, default: 50

**cURL Example:**
```bash
curl -X GET "http://localhost:8000/api/v1/translations/search?q=hello&skip=0&limit=20" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Python Example:**
```python
import requests

token = "YOUR_ACCESS_TOKEN"
headers = {"Authorization": f"Bearer {token}"}

# Search for "hello"
response = requests.get(
    "http://localhost:8000/api/v1/translations/search",
    params={"q": "hello", "skip": 0, "limit": 20},
    headers=headers
)

data = response.json()
print(f"Found {data['total']} results")

for translation in data['data']:
    print(f"  [{translation['source_language']}→{translation['target_language']}] {translation['source_text']}")
```

---

### 3️⃣ Lọc Translations

**Endpoint:** `GET /api/v1/translations/filter`

**Query Parameters:**
- `source_language` (string, optional): Source language code
- `target_language` (string, optional): Target language code
- `translation_type` (string, optional): 'text', 'voice', or 'image'
- `skip` (int, optional): Records to skip, default: 0
- `limit` (int, optional): Records per page, default: 50

**cURL Examples:**

Filter by language pair:
```bash
curl -X GET "http://localhost:8000/api/v1/translations/filter?source_language=en&target_language=vi" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Filter by type:
```bash
curl -X GET "http://localhost:8000/api/v1/translations/filter?translation_type=text" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Python Example:**
```python
import requests

token = "YOUR_ACCESS_TOKEN"
headers = {"Authorization": f"Bearer {token}"}

# Get all text translations from English to Vietnamese
response = requests.get(
    "http://localhost:8000/api/v1/translations/filter",
    params={
        "source_language": "en",
        "target_language": "vi",
        "translation_type": "text",
        "skip": 0,
        "limit": 50
    },
    headers=headers
)

data = response.json()
print(f"Found {data['total']} translations")
```

---

### 4️⃣ Lấy Chi tiết Một Translation

**Endpoint:** `GET /api/v1/translations/{translation_id}`

**Path Parameters:**
- `translation_id` (int): ID of translation

**cURL Example:**
```bash
curl -X GET "http://localhost:8000/api/v1/translations/12345" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Python Example:**
```python
import requests

token = "YOUR_ACCESS_TOKEN"
headers = {"Authorization": f"Bearer {token}"}

translation_id = 12345
response = requests.get(
    f"http://localhost:8000/api/v1/translations/{translation_id}",
    headers=headers
)

if response.status_code == 200:
    translation = response.json()['data']
    print(f"Source: {translation['source_text']}")
    print(f"Translated: {translation['translated_text']}")
    print(f"Type: {translation['translation_type']}")
    print(f"Created: {translation['created_at']}")
else:
    print(f"Error: {response.json()['detail']['message']}")
```

---

### 5️⃣ Xóa Một Translation

**Endpoint:** `DELETE /api/v1/translations/{translation_id}`

**Path Parameters:**
- `translation_id` (int): ID of translation to delete

**cURL Example:**
```bash
curl -X DELETE "http://localhost:8000/api/v1/translations/12345" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Python Example:**
```python
import requests

token = "YOUR_ACCESS_TOKEN"
headers = {"Authorization": f"Bearer {token}"}

translation_id = 12345
response = requests.delete(
    f"http://localhost:8000/api/v1/translations/{translation_id}",
    headers=headers
)

if response.status_code == 200:
    print("Translation deleted successfully")
else:
    print(f"Error: {response.json()['detail']['message']}")
```

---

### 6️⃣ Xóa Hàng loạt Translations

**Endpoint:** `POST /api/v1/translations/bulk-delete`

**Request Body:**
```json
{
  "translation_ids": [123, 456, 789, 1001]
}
```

**cURL Example:**
```bash
curl -X POST "http://localhost:8000/api/v1/translations/bulk-delete" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"translation_ids": [123, 456, 789]}'
```

**Python Example:**
```python
import requests

token = "YOUR_ACCESS_TOKEN"
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# Delete 3 translations
ids_to_delete = [123, 456, 789]
response = requests.post(
    "http://localhost:8000/api/v1/translations/bulk-delete",
    json={"translation_ids": ids_to_delete},
    headers=headers
)

if response.status_code == 200:
    result = response.json()['data']
    print(f"Deleted: {result['deleted_count']}")
    print(f"Failed: {result['failed_count']}")
```

---

## 🎯 Frontend Implementation Examples

### React - Infinite Scroll (Load More)

```javascript
import { useState, useEffect } from 'react';

function TranslationHistory() {
  const [translations, setTranslations] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(0);
  const pageSize = 50;

  const loadMoreTranslations = async () => {
    setLoading(true);
    try {
      const skip = page * pageSize;
      const response = await fetch(
        `/api/v1/translations/history?skip=${skip}&limit=${pageSize}`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      const data = await response.json();
      
      // Append to existing translations
      setTranslations(prev => [...prev, ...data.data]);
      setTotal(data.total);
      setPage(prev => prev + 1);
    } catch (error) {
      console.error('Failed to load translations:', error);
    } finally {
      setLoading(false);
    }
  };

  const hasMore = (page * pageSize + pageSize) < total;

  return (
    <div>
      <h2>Translation History ({total})</h2>
      <ul>
        {translations.map(t => (
          <li key={t.id}>
            {t.source_text} → {t.translated_text}
            <small> ({t.created_at})</small>
          </li>
        ))}
      </ul>
      {hasMore && !loading && (
        <button onClick={loadMoreTranslations}>Load More</button>
      )}
      {loading && <p>Loading...</p>}
    </div>
  );
}

export default TranslationHistory;
```

### React - Search

```javascript
function SearchTranslations() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [total, setTotal] = useState(0);

  const handleSearch = async (searchText) => {
    if (!searchText.trim()) {
      setResults([]);
      return;
    }

    try {
      const response = await fetch(
        `/api/v1/translations/search?q=${encodeURIComponent(searchText)}&limit=50`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      const data = await response.json();
      setResults(data.data);
      setTotal(data.total);
    } catch (error) {
      console.error('Search failed:', error);
    }
  };

  return (
    <div>
      <input
        placeholder="Search translations..."
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);
          handleSearch(e.target.value);
        }}
      />
      <p>Found {total} results</p>
      <ul>
        {results.map(t => (
          <li key={t.id}>
            <strong>{t.source_text}</strong> → {t.translated_text}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### Flutter - Pagination

```dart
// In your Flutter app
import 'package:http/http.dart' as http;
import 'dart:convert';

class TranslationAPI {
  static const String baseUrl = 'http://localhost:8000/api/v1';
  final String token;

  TranslationAPI({required this.token});

  Future<TranslationHistoryResponse> getHistory({
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/translations/history?skip=$skip&limit=$limit'
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return TranslationHistoryResponse.fromJson(
        jsonDecode(response.body),
      );
    } else {
      throw Exception('Failed to fetch translations');
    }
  }

  Future<TranslationHistoryResponse> search({
    required String query,
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/translations/search?q=${Uri.encodeComponent(query)}&skip=$skip&limit=$limit'
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return TranslationHistoryResponse.fromJson(
        jsonDecode(response.body),
      );
    } else {
      throw Exception('Search failed');
    }
  }

  Future<void> deleteMultiple({required List<int> ids}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/translations/bulk-delete'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'translation_ids': ids}),
    );

    if (response.statusCode != 200) {
      throw Exception('Bulk delete failed');
    }
  }
}

// Model classes
class TranslationHistoryResponse {
  final String status;
  final List<TranslationItem> data;
  final int total;

  TranslationHistoryResponse({
    required this.status,
    required this.data,
    required this.total,
  });

  factory TranslationHistoryResponse.fromJson(Map<String, dynamic> json) {
    return TranslationHistoryResponse(
      status: json['status'],
      data: (json['data'] as List)
          .map((item) => TranslationItem.fromJson(item))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}

class TranslationItem {
  final int id;
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String translationType;
  final bool isCached;
  final DateTime createdAt;

  TranslationItem({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translationType,
    required this.isCached,
    required this.createdAt,
  });

  factory TranslationItem.fromJson(Map<String, dynamic> json) {
    return TranslationItem(
      id: json['id'],
      sourceText: json['source_text'],
      translatedText: json['translated_text'],
      sourceLanguage: json['source_language'],
      targetLanguage: json['target_language'],
      translationType: json['translation_type'],
      isCached: json['is_cached'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
```

---

## ⚡ Performance Tips

### For Frontend

1. **Pagination**: Luôn sử dụng phân trang, không bao giờ fetch tất cả
   ```javascript
   // ✅ Đúng
   const response = await fetch('/api/v1/translations/history?skip=0&limit=50');
   
   // ❌ Sai
   const response = await fetch('/api/v1/translations/history?limit=10000');
   ```

2. **Search efficiently**: Đặt debounce để giảm request
   ```javascript
   const [searchQuery, setSearchQuery] = useState('');
   
   const debouncedSearch = useCallback(
     debounce((query) => handleSearch(query), 500),
     []
   );
   
   const handleChange = (e) => {
     setSearchQuery(e.target.value);
     debouncedSearch(e.target.value);
   };
   ```

3. **Caching**: Cache kết quả trên client
   ```javascript
   const cache = new Map();
   
   const getTranslations = async (skip, limit) => {
     const key = `${skip}:${limit}`;
     if (cache.has(key)) return cache.get(key);
     
     const response = await fetch(`/api/v1/translations/history?skip=${skip}&limit=${limit}`);
     cache.set(key, await response.json());
     return cache.get(key);
   };
   ```

### For Backend

- ✅ SQL queries optimized with INDEX on (user_id, created_at)
- ✅ COUNT query used instead of fetching all records
- ✅ Pagination limit capped at 100
- ✅ Soft delete (no physical deletion)

---

## 🐛 Troubleshooting

### Issue: 401 Unauthorized
**Solution**: Check if token is valid and not expired
```bash
# Get a new token
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'
```

### Issue: Empty results
**Solution**: Check if user has any translations
```bash
# Create a translation first
curl -X POST http://localhost:8000/api/v1/translations \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source_text":"Hello",
    "source_language":"en",
    "target_language":"vi"
  }'
```

### Issue: 404 Not Found
**Solution**: Check translation ID exists and belongs to current user
```bash
# Search to find valid IDs
curl -X GET "http://localhost:8000/api/v1/translations/search?q=hello" \
  -H "Authorization: Bearer TOKEN"
```

---

## 📊 API Limits & Constraints

| Constraint | Value | Note |
|-----------|-------|------|
| Max limit per page | 100 | Set in query param |
| Default limit | 50 | If not specified |
| Max search text | 500 chars | Search query |
| Max bulk delete | 100 IDs | Per request |
| Response timeout | 30s | Server timeout |
| Rate limit | 1000/minute | Per user |

---

## 🔐 Security

- ✅ All endpoints require authentication (Bearer token)
- ✅ Users can only see their own translations
- ✅ Soft delete preserves data for analytics
- ✅ Input validation on all parameters
- ✅ SQL injection prevention (ORM used)

---

## 📝 Testing Checklist

- [ ] Test pagination with different skip/limit values
- [ ] Test search with special characters
- [ ] Test filter with multiple parameters
- [ ] Test bulk delete with max 100 IDs
- [ ] Test error cases (404, 400, 500)
- [ ] Load test with 1000+ records
- [ ] Test caching with repeated queries

