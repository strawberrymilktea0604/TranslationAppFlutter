# API Quản lý Lịch sử Dịch thuật

## Tổng quan
API quản lý lịch sử dịch thuật với hỗ trợ **phân trang, tìm kiếm, lọc, và xóa hàng loạt** để FE không bị nghẽn khi tải dữ liệu lịch sử dài.

### Đặc điểm chính
✅ **Phân trang hiệu quả**: Sử dụng SQL COUNT thay vì fetch tất cả records  
✅ **Tìm kiếm toàn văn bản**: Full-text search trong source và translated text  
✅ **Lọc linh hoạt**: Lọc theo ngôn ngữ, loại dịch (text/voice/image)  
✅ **Xóa hàng loạt**: Xóa tối đa 100 translations trong một request  
✅ **Soft Delete**: Giữ lại dữ liệu cho analytics  

---

## Danh sách Endpoints

### 1. Tạo Dịch thuật (Create)
```
POST /api/v1/translations
```
Dịch text và lưu lịch sử (nếu có user_id).

**Request:**
```json
{
  "source_text": "Hello, how are you?",
  "source_language": "en",
  "target_language": "vi",
  "translation_type": "text"
}
```

**Response (Cache Hit):**
```json
{
  "status": "success",
  "data": {
    "source_text": "Hello, how are you?",
    "translated_text": "Xin chào, bạn khỏe không?",
    "source_language": "en",
    "target_language": "vi",
    "is_cached": true,
    "response_time_ms": 15.5
  }
}
```

**Status Code:** 200

---

### 2. Lấy Chi tiết Dịch thuật (Get Detail)
```
GET /api/v1/translations/{translation_id}
```
Lấy thông tin chi tiết một translation (chỉ xem được của chính user).

**Path Parameters:**
- `translation_id` (int): ID của translation

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 123456,
    "source_text": "Hello",
    "translated_text": "Xin chào",
    "source_language": "en",
    "target_language": "vi",
    "translation_type": "text",
    "is_cached": false,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

**Status Codes:**
- 200: OK
- 404: Not found or unauthorized

---

### 3. Lấy Lịch sử Dịch thuật (Get History - Paginated)
```
GET /api/v1/translations/history
```
Lấy lịch sử dịch thuật của user với phân trang.

**Query Parameters:**
- `skip` (int): Records to skip, default: 0, min: 0
- `limit` (int): Records per page, default: 50, min: 1, max: 100

**Example:**
```
GET /api/v1/translations/history?skip=0&limit=20
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
    },
    {
      "id": 1002,
      "source_text": "Good morning",
      "translated_text": "Chào buổi sáng",
      "source_language": "en",
      "target_language": "vi",
      "translation_type": "text",
      "is_cached": true,
      "created_at": "2024-01-15T10:25:00Z"
    }
  ],
  "total": 1500
}
```

**Status Code:** 200

---

### 4. Tìm kiếm Lịch sử (Search)
```
GET /api/v1/translations/search
```
Tìm kiếm translations trong source hoặc translated text.

**Query Parameters:**
- `q` (string, required): Search query, 1-500 chars
- `skip` (int): Records to skip, default: 0
- `limit` (int): Records per page, default: 50, max: 100

**Example:**
```
GET /api/v1/translations/search?q=hello&skip=0&limit=20
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1001,
      "source_text": "Hello everyone",
      "translated_text": "Xin chào mọi người",
      "source_language": "en",
      "target_language": "vi",
      "translation_type": "text",
      "is_cached": false,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "total": 45
}
```

**Status Codes:**
- 200: OK
- 400: Invalid search query

---

### 5. Lọc Lịch sử (Filter)
```
GET /api/v1/translations/filter
```
Lọc translations theo ngôn ngữ, loại dịch, hoặc kết hợp.

**Query Parameters:**
- `source_language` (string, optional): Source language code (e.g., 'en', 'vi')
- `target_language` (string, optional): Target language code
- `translation_type` (string, optional): Type: 'text', 'voice', 'image'
- `skip` (int): Records to skip, default: 0
- `limit` (int): Records per page, default: 50, max: 100

**Examples:**

Filter by language pair:
```
GET /api/v1/translations/filter?source_language=en&target_language=vi&skip=0&limit=20
```

Filter by translation type:
```
GET /api/v1/translations/filter?translation_type=text&skip=0&limit=50
```

Filter by source language:
```
GET /api/v1/translations/filter?source_language=en&skip=0&limit=30
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
  "total": 250
}
```

**Status Codes:**
- 200: OK
- 400: Invalid filter parameters

---

### 6. Xóa Một Dịch thuật (Delete)
```
DELETE /api/v1/translations/{translation_id}
```
Xóa một translation (soft delete).

**Path Parameters:**
- `translation_id` (int): ID to delete

**Response:**
```json
{
  "status": "success",
  "data": {
    "message": "Translation deleted successfully"
  }
}
```

**Status Codes:**
- 200: OK
- 404: Not found or unauthorized
- 500: Server error

---

### 7. Xóa Hàng loạt (Bulk Delete)
```
POST /api/v1/translations/bulk-delete
```
Xóa nhiều translations trong một request (tối đa 100).

**Request Body:**
```json
{
  "translation_ids": [123, 456, 789, 1001, 1002]
}
```

**Constraints:**
- Minimum 1 translation
- Maximum 100 translations per request

**Response:**
```json
{
  "status": "success",
  "data": {
    "deleted_count": 5,
    "failed_count": 0
  }
}
```

**Status Codes:**
- 200: OK
- 400: Invalid request (too many IDs, etc.)
- 500: Server error

---

### 8. Cache Statistics (Optional)
```
GET /api/v1/translations/cache/stats
```
Lấy thống kê cache (cho admin).

**Response:**
```json
{
  "status": "success",
  "data": {
    "message": "Cache statistics retrieved",
    "stats": {
      "hit_rate": 0.85,
      "total_cached": 5000,
      "memory_usage_mb": 125.5
    }
  }
}
```

---

### 9. Clear Cache (Optional)
```
POST /api/v1/translations/cache/clear
```
Xóa tất cả translation cache (admin only).

**Response:**
```json
{
  "status": "success",
  "data": {
    "message": "Translation cache cleared"
  }
}
```

---

## Pagination Best Practices

### Frontend Pagination Implementation

```javascript
// Example: Infinite scroll or load more
let page = 0;
const pageSize = 50;

async function loadMoreTranslations() {
  const skip = page * pageSize;
  const response = await fetch(
    `/api/v1/translations/history?skip=${skip}&limit=${pageSize}`,
    { headers: { Authorization: `Bearer ${token}` } }
  );
  const data = await response.json();
  
  const hasMore = (skip + data.data.length) < data.total;
  
  return {
    translations: data.data,
    total: data.total,
    hasMore: hasMore
  };
}
```

### Pagination Strategy

| Loại | Skip | Limit | Dùng cho |
|------|------|-------|----------|
| Trang đầu | 0 | 50 | First load |
| Trang sau | 50 * n | 50 | Load more |
| Last page | total - 50 | 50 | Go to last |

---

## Error Handling

### Common Error Responses

**400 - Bad Request:**
```json
{
  "status": "error",
  "code": "INVALID_REQUEST",
  "message": "Invalid pagination parameters"
}
```

**404 - Not Found:**
```json
{
  "status": "error",
  "code": "NOT_FOUND",
  "message": "Translation not found"
}
```

**500 - Server Error:**
```json
{
  "status": "error",
  "code": "FETCH_FAILED",
  "message": "Failed to fetch translations"
}
```

---

## Performance Optimization

### Query Performance
- ✅ **Efficient COUNT**: Sử dụng SQL COUNT() thay vì fetch all
- ✅ **Indexed Queries**: user_id, created_at được index
- ✅ **Limit 100**: Max limit tránh quá tải
- ✅ **Soft Delete**: Không xóa, chỉ mark is_deleted=True

### Response Time Targets
- Paginated list: **< 200ms**
- Search with 500 results: **< 500ms**
- Filter operations: **< 300ms**

---

## Testing

### Curl Examples

Get history (first 20 records):
```bash
curl -X GET "http://localhost:8000/api/v1/translations/history?skip=0&limit=20" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Search translations:
```bash
curl -X GET "http://localhost:8000/api/v1/translations/search?q=hello&skip=0&limit=20" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Filter by language:
```bash
curl -X GET "http://localhost:8000/api/v1/translations/filter?source_language=en&target_language=vi" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Bulk delete:
```bash
curl -X POST "http://localhost:8000/api/v1/translations/bulk-delete" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"translation_ids": [123, 456, 789]}'
```

---

## Implementation Checklist

- [x] Model Translation (với is_deleted field)
- [x] Repository methods (get_user_translations, search_translations, filter_by_language, delete_multiple)
- [x] Service layer (hỗ trợ các phương thức trên)
- [x] Schemas (TranslationResponse, BulkDeleteRequest/Response, etc.)
- [x] Endpoints (GET history, search, filter, detail; POST bulk-delete; DELETE one)
- [x] Pagination optimization (SQL COUNT)
- [x] Error handling
- [ ] Unit tests
- [ ] Integration tests
- [ ] Load testing (1000+ records)

---

## Changelog

### Version 1.0 - 2024-01-15
- ✅ API Lịch sử Dịch thuật với phân trang
- ✅ Tìm kiếm toàn văn bản
- ✅ Lọc theo ngôn ngữ và loại dịch
- ✅ Xóa hàng loạt (max 100)
- ✅ Soft delete (giữ lại dữ liệu)
- ✅ Optimized pagination (SQL COUNT)
