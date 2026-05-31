# Vocabulary API - Quick Start Guide

## 🚀 Quick Setup (5 mins)

### Backend

**1. Kiểm tra models (đã có sẵn)**
```python
# backend/app/models/translation.py
class Vocabulary(Base):
    __tablename__ = "vocabularies"
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=False)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"))
    translation_id = Column(BigInteger, ForeignKey("translations.id", ondelete="CASCADE"))
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))
    updated_at = Column(DateTime(timezone=True), server_default=text('now()'), onupdate=text('now()'))
```

**2. Files mới được tạo:**
- ✅ `app/schemas/vocabulary.py` - Pydantic models
- ✅ `app/repositories/vocabulary_repository.py` - Database layer
- ✅ `app/services/vocabulary_service.py` - Business logic
- ✅ `app/api/v1/endpoints/vocabulary.py` - REST endpoints
- ✅ `app/api/v1/api.py` - Updated router

**3. Start server:**
```bash
# Terminal 1: Start API
cd backend
uvicorn app.main:app --reload

# Terminal 2: Check health
curl http://localhost:8000/api/v1/health
```

**4. Check API docs:**
```
http://localhost:8000/docs  # Swagger UI
```

---

## 📱 Frontend Integration

### For Authenticated Users

```dart
// 1. Add to vocabulary (save for learning)
await vocabularyService.addToVocabulary(translationId);

// 2. Get vocabulary list
final vocabs = await vocabularyService.getVocabularies(
  page: 1,
  pageSize: 20,
  search: 'hello', // optional
);

// 3. Get details
final detail = await vocabularyService.getVocabularyDetail(vocabId);

// 4. Remove from vocabulary
await vocabularyService.removeFromVocabulary(vocabId);

// 5. Get statistics
final stats = await vocabularyService.getStats();
```

### For Guest Users (Local Storage)

```dart
// Use local SQLite instead
await localVocabularyService.saveVocabularyLocally(translation);
final localVocabs = await localVocabularyService.getLocalVocabularies();
```

---

## 🔗 API Endpoints Summary

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/vocabularies` | Add to vocabulary |
| POST | `/api/v1/vocabularies/batch` | Add multiple (max 50) |
| GET | `/api/v1/vocabularies` | List with pagination |
| GET | `/api/v1/vocabularies/{id}` | Get details |
| DELETE | `/api/v1/vocabularies/{id}` | Remove entry |
| DELETE | `/api/v1/vocabularies/batch/remove` | Remove multiple |
| POST | `/api/v1/vocabularies/{id}/restore` | Restore deleted |
| GET | `/api/v1/vocabularies/stats/summary` | Get statistics |

---

## 🧪 Testing with cURL

### Add to Vocabulary
```bash
TOKEN="your_access_token_here"

curl -X POST http://localhost:8000/api/v1/vocabularies \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"translation_id": 123456789}'
```

### Get Vocabulary List
```bash
curl -X GET "http://localhost:8000/api/v1/vocabularies?page=1&page_size=20" \
  -H "Authorization: Bearer $TOKEN"
```

### Search
```bash
curl -X GET "http://localhost:8000/api/v1/vocabularies?search=hello" \
  -H "Authorization: Bearer $TOKEN"
```

### Get Statistics
```bash
curl -X GET http://localhost:8000/api/v1/vocabularies/stats/summary \
  -H "Authorization: Bearer $TOKEN"
```

### Delete Entry
```bash
curl -X DELETE http://localhost:8000/api/v1/vocabularies/987654321 \
  -H "Authorization: Bearer $TOKEN"
```

---

## 📊 Data Flow

```
Flutter App
    ↓
[Guest] → Local SQLite (offline, no sync)
    ↓
[User] → Cloud API → Server → PostgreSQL
    ↓
[User] → Sync across devices
```

---

## 🛠 Troubleshooting

### "Translation not found"
```
❌ Problem: translation_id doesn't exist or doesn't belong to user
✅ Solution: 
  1. Make sure translation was created by user
  2. Verify translation_id is correct
```

### "Already in vocabulary"
```
❌ Problem: Same translation_id already in vocabulary
✅ Solution: Check if user already saved this translation
```

### "Unauthorized (401)"
```
❌ Problem: Token expired or missing
✅ Solution: 
  1. Refresh token
  2. Re-login if needed
```

### "Not Found (404)"
```
❌ Problem: Vocabulary entry not found
✅ Solution:
  1. Check vocabulary_id is correct
  2. Entry might be already deleted
```

---

## 📝 Example Response

**Add to Vocabulary:**
```json
{
  "success": true,
  "message": "Translation added to vocabulary successfully",
  "data": {
    "vocabulary_id": 987654321,
    "created_at": "2026-05-14T10:30:00+00:00"
  }
}
```

**Get List:**
```json
{
  "items": [
    {
      "id": 987654321,
      "source_text": "Hello",
      "translated_text": "Xin chào",
      "source_language": "en",
      "target_language": "vi",
      "translation_type": "text",
      "created_at": "2026-05-14T10:30:00+00:00"
    }
  ],
  "total": 15,
  "page": 1,
  "page_size": 20,
  "total_pages": 1,
  "has_next": false,
  "has_prev": false
}
```

---

## 🚀 Next Steps

1. **Test with Swagger UI:** `http://localhost:8000/docs`
2. **Implement Flutter UI** for vocabulary browser
3. **Add local caching** for better UX
4. **Implement search** in Flutter app
5. **Add statistics** widget to show progress

---

## 📚 Full Documentation

See [VOCABULARY_API.md](./VOCABULARY_API.md) for complete API reference with:
- Detailed endpoint specifications
- All response schemas
- Error handling guide
- Guest vs User implementation
- Caching strategies
- Future features

