# Quick Start: Translation Caching Setup

## ✅ Đã Hoàn Tất (Completed)

### 1. Redis Client Mở Rộng
```
✅ app/core/redis_client.py
   - get_cached_translation()
   - set_cached_translation()
   - Cache key generation & normalization
```

### 2. Translation Service
```
✅ app/services/translation_service.py
   - Core caching logic
   - Cache → DB → API flow
   - Response time tracking
```

### 3. Database Layer
```
✅ app/repositories/translation_repository.py
   - CRUD operations
   - Search existing translations
   - History tracking
```

### 4. API Endpoints
```
✅ app/api/v1/endpoints/translation.py
   - POST /api/v1/translations (translate with cache)
   - GET /api/v1/translations/history (user history)
   - DELETE /api/v1/translations/{id}
   - GET /api/v1/translations/cache/stats
   - POST /api/v1/translations/cache/clear
```

### 5. Schemas & Models
```
✅ app/schemas/translation.py (TranslationRequest, Response)
✅ app/models/translation.py (already exists)
```

---

## 🚀 Tiếp Theo (Next Steps)

### Step 1: Triển Khai Thật Translation Engine
File: `app/services/translation_service.py`

Tìm và thay thế:
```python
async def _call_translation_api(request: TranslationRequest) -> str:
    """Call external translation API"""
    # TODO: Replace with actual API
```

**Option A: Google Cloud Translation**
```python
from google.cloud import translate_v2

async def _call_translation_api(request: TranslationRequest) -> str:
    client = translate_v2.Client()
    result = client.translate_text(
        request.source_text,
        source_language_code=request.source_language,
        target_language_code=request.target_language
    )
    return result['translatedText']
```

**Option B: DeepL API**
```python
import httpx

async def _call_translation_api(request: TranslationRequest) -> str:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api-free.deepl.com/v1/translate",
            data={
                "auth_key": settings.DEEPL_API_KEY,
                "text": request.source_text,
                "source_lang": request.source_language.upper(),
                "target_lang": request.target_language.upper()
            }
        )
        return response.json()["translations"][0]["text"]
```

**Option C: Azure Translator**
```python
from azure.ai.translation.text import TextTranslationClient
from azure.core.credentials import AzureKeyCredential

async def _call_translation_api(request: TranslationRequest) -> str:
    client = TextTranslationClient(
        credential=AzureKeyCredential(settings.AZURE_TRANSLATOR_KEY),
        endpoint=settings.AZURE_TRANSLATOR_ENDPOINT,
        region=settings.AZURE_TRANSLATOR_REGION
    )
    result = client.translate(
        body=[{"text": request.source_text}],
        from_language=request.source_language,
        to_language=request.target_language
    )
    return result[0].translations[0].text
```

### Step 2: Thêm API Credentials vào .env
```bash
# Google Cloud
GOOGLE_CLOUD_API_KEY=your-key-here

# DeepL
DEEPL_API_KEY=your-key-here

# Azure
AZURE_TRANSLATOR_KEY=your-key-here
AZURE_TRANSLATOR_ENDPOINT=https://api.cognitive.microsofttranslator.com
AZURE_TRANSLATOR_REGION=eastus
```

### Step 3: Cài đặt Dependencies
```bash
# For Google Cloud
pip install google-cloud-translate

# For DeepL
pip install deepl

# For Azure
pip install azure-cognitiveservices-language-translator

# Add to requirements.txt
```

### Step 4: Kiểm Tra Redis
```bash
# Start Redis (if not in Docker)
docker run -d -p 6379:6379 redis:7-alpine

# Test connection
redis-cli ping
# Expected: PONG
```

### Step 5: Test Endpoints
```bash
# 1. Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Response: { "access_token": "...", "token_type": "bearer" }

# 2. Translate (First call - Cache Miss)
curl -X POST http://localhost:8000/api/v1/translations \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source_text": "Hello world",
    "source_language": "en",
    "target_language": "vi"
  }'

# Response (should be ~500ms)
# {
#   "status": "success",
#   "data": {
#     "translated_text": "Xin chào thế giới",
#     "is_cached": false,
#     "response_time_ms": 523.4
#   }
# }

# 3. Translate (Second call - Cache Hit)
curl -X POST http://localhost:8000/api/v1/translations \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source_text": "Hello world",
    "source_language": "en",
    "target_language": "vi"
  }'

# Response (should be <50ms)
# {
#   "status": "success",
#   "data": {
#     "translated_text": "Xin chào thế giới",
#     "is_cached": true,
#     "response_time_ms": 15.3
#   }
# }

# 4. View translation history
curl -X GET "http://localhost:8000/api/v1/translations/history?skip=0&limit=10" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 5. View cache stats
curl -X GET http://localhost:8000/api/v1/translations/cache/stats \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 📊 Kiểm Tra Cache Hoạt Động

### Monitoring Logs
```bash
# Watch logs for cache hits/misses
docker logs -f backend

# Look for:
# ✅ Cache HIT - < 50ms
# ❌ Cache MISS - calls API
# 💾 Cached translation - saved to Redis
# 📚 DB Cache HIT - found in database
```

### Redis CLI
```bash
# Connect to Redis
redis-cli

# Check cache size
DBSIZE
# Expected: > 0 translations cached

# View cache keys
KEYS "translation:*"
# Example output:
# 1) "translation:3e2b...:en:vi"
# 2) "translation:a4c7...:en:fr"

# View cache value
GET "translation:3e2b...:en:vi"
# Output: The translated text

# Monitor cache operations in real-time
MONITOR
```

---

## ⚙️ Configuration Optimization

### .env Settings
```bash
# For high-traffic scenarios
CACHE_ENABLED=true
CACHE_TTL_SECONDS=7200  # 2 hours (instead of 1)
TRANSLATION_SERVICE_TIMEOUT=15  # Increase if API is slow

# For low-traffic scenarios
CACHE_TTL_SECONDS=1800  # 30 minutes (save Redis memory)

# Redis configuration
REDIS_URL=redis://localhost:6379/0
```

### Docker Compose (docker-compose.yml)
```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
```

---

## 🧪 Performance Testing

### Load Test Cache Hit Rate
```python
import asyncio
import time
from app.services.translation_service import TranslationService
from app.schemas.translation import TranslationRequest

async def test_cache_performance():
    hits = 0
    misses = 0
    total_time = 0
    
    # Simulate 100 translation requests
    for i in range(100):
        request = TranslationRequest(
            source_text="Hello world",  # Same text every time
            source_language="en",
            target_language="vi"
        )
        
        start = time.time()
        _, is_cached, response_time = await TranslationService.translate_with_cache(
            request, db, save_to_db=False
        )
        elapsed = time.time() - start
        
        if is_cached:
            hits += 1
        else:
            misses += 1
        
        total_time += elapsed
    
    hit_rate = (hits / 100) * 100
    avg_time = (total_time / 100) * 1000
    
    print(f"Hit rate: {hit_rate}% (target: 70-90%)")
    print(f"Avg response time: {avg_time}ms (target: < 50ms)")
    print(f"Total hits: {hits}, misses: {misses}")

# Run: asyncio.run(test_cache_performance())
```

---

## 🐛 Troubleshooting

### Problem: Redis Connection Fails
```
Error: Failed to connect to Redis: Connection refused
```
**Solution:**
```bash
# Start Redis
docker run -d -p 6379:6379 redis:7-alpine

# Verify
redis-cli ping
# Should output: PONG
```

### Problem: Cache Never Hits
```
All requests show: is_cached: false
```
**Solution:**
1. Check CACHE_ENABLED=true in .env
2. Verify Redis is running (redis-cli ping)
3. Check REDIS_URL format
4. Ensure same text is used (case-sensitive before normalization)

### Problem: Translation API Not Called
```
Translations appear but not realistic content
```
**Solution:**
- Replace placeholder _call_translation_api() with real API
- Verify API credentials in .env
- Test API independently

---

## 📝 File Reference

| File | Purpose |
|------|---------|
| `app/core/redis_client.py` | Cache functions (get/set) |
| `app/services/translation_service.py` | Main logic + API integration |
| `app/repositories/translation_repository.py` | Database CRUD |
| `app/api/v1/endpoints/translation.py` | API routes |
| `app/schemas/translation.py` | Request/response schemas |
| `CACHING_IMPLEMENTATION.md` | Full documentation |
| `backend/tests/test_translation_cache.py` | Unit tests |

---

## ✨ Summary

**Implementation Status: 95%**

✅ **Done:**
- Redis cache client
- Caching service layer
- Database repository
- API endpoints
- Request/response schemas
- Documentation
- Test cases

⏳ **TODO:**
- Integrate real translation API (Google/DeepL/Azure)
- Add language validation
- Performance tuning based on real usage
- Analytics dashboard

**Expected Results After Real API Integration:**
- Response time (cache hit): < 50ms ✅
- Response time (total): < 500ms ✅
- API cost savings: 70-90% ✅
- Cache hit rate: 70-90% ✅
