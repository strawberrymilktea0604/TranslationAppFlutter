# Database Backup & Redis Static Content Caching Guide

## 📋 Overview

This document describes the two major infrastructure features recently added to the TranslationAppFlutter backend:

1. **Database Backup Mechanism** - Automated and manual PostgreSQL database backups
2. **Redis Static Content Caching** - Efficient caching of static assets and API responses

---

## 🔄 Database Backup System

### Features

✅ **Automated Daily Backups** - Scheduled at 2:00 AM automatically  
✅ **Manual Backup Trigger** - Create backups on-demand via API  
✅ **Automatic Compression** - Backups compressed with gzip to save space  
✅ **Retention Policy** - Keeps last 7 backups automatically  
✅ **Database Restoration** - Restore from any previous backup  
✅ **Backup Listing** - View all available backups with metadata  

### Architecture

```
DatabaseBackupService
├── create_backup()          # Create backup using pg_dump
├── restore_backup()         # Restore from backup
├── get_backup_list()        # List all backups
├── delete_backup()          # Delete specific backup
└── _cleanup_old_backups()   # Automatic retention management

BackupScheduler
└── initialize_scheduler()   # Setup APScheduler for daily backups
```

### Setup & Configuration

#### 1. Installation

Backup dependencies are already in `requirements.txt`:

```bash
apscheduler==3.10.4
```

#### 2. Backup Directory

Backups are stored in:
```
/backups/database/  # Inside container volume
```

Update `docker-compose.yml` (already done):
```yaml
volumes:
  - backups:/backups  # Persistent volume for backups
```

#### 3. Environment Variables

```bash
# In backend/.env
BACKUP_DIR=/backups/database
```

### Usage

#### Create Automatic Daily Backups

The backup scheduler automatically creates backups at **2:00 AM daily**. This is initialized in `app/main.py` during application startup.

Check logs:
```
✅ Database backup scheduler initialized and started
✅ Backup created successfully: backup_20260517_020000 (150.45 MB)
```

#### Manual Backup via API

**Create Backup:**
```bash
curl -X POST http://localhost:8000/api/v1/management/backups/create \
  -H "Authorization: Bearer {admin_token}" \
  -H "Content-Type: application/json"
```

Optional: Specify backup name
```bash
curl -X POST "http://localhost:8000/api/v1/management/backups/create?backup_name=before_migration" \
  -H "Authorization: Bearer {admin_token}"
```

**List Backups:**
```bash
curl -X GET http://localhost:8000/api/v1/management/backups/list \
  -H "Authorization: Bearer {admin_token}"
```

Response:
```json
{
  "count": 3,
  "backups": [
    {
      "filename": "backup_20260517_020000.sql.gz",
      "size_mb": 150.45,
      "created_at": "2026-05-17T02:00:00",
      "path": "/backups/database/backup_20260517_020000.sql.gz"
    }
  ]
}
```

**Restore Backup:**
```bash
curl -X POST "http://localhost:8000/api/v1/management/backups/backup_20260517_020000.sql.gz/restore" \
  -H "Authorization: Bearer {admin_token}"
```

⚠️ **WARNING:** Restoration will overwrite the current database!

**Delete Backup:**
```bash
curl -X DELETE "http://localhost:8000/api/v1/management/backups/backup_20260517_020000.sql.gz" \
  -H "Authorization: Bearer {admin_token}"
```

**Check Backup Health:**
```bash
curl -X GET http://localhost:8000/api/v1/management/health/backup
```

### Backup File Format

Backups use PostgreSQL custom binary format (compressed by pg_dump):
- **Format:** PostgreSQL Custom (pg_dump -F c)
- **Compression:** Further gzipped (.sql.gz)
- **Restoration:** Using `pg_restore` command

### Retention Policy

The system automatically maintains a retention policy:
- **Keep last 7 backups** (adjustable via `max_backups` parameter)
- **Automatic cleanup** when creating new backups exceeds limit
- **Logs cleanup** operations

Update retention in `app/services/backup_service.py`:
```python
backup_service = DatabaseBackupService(
    db_url=settings.DATABASE_URL,
    max_backups=7,  # Change this value
    compress=True,
)
```

### Restore from Backup

**Step 1: List available backups**
```bash
curl -X GET http://localhost:8000/api/v1/management/backups/list \
  -H "Authorization: Bearer {admin_token}"
```

**Step 2: Initiate restoration**
```bash
curl -X POST "http://localhost:8000/api/v1/management/backups/{backup_filename}/restore" \
  -H "Authorization: Bearer {admin_token}"
```

**Step 3: Monitor the process**
- Backups run in background
- Database may be temporarily unavailable
- Check application logs for completion

### Manual Backup from Command Line

```bash
# Enter the database container
docker-compose exec db bash

# Create backup manually
pg_dump -h db -U postgres -F c -d translation_app > /backups/database/manual_backup.sql

# Exit container
exit
```

---

## 🚀 Redis Static Content Caching

### Features

✅ **Multi-prefix Caching** - Organized cache with prefixes  
✅ **TTL Management** - Configurable expiration times  
✅ **LRU Eviction** - Automatic memory management  
✅ **Persistence** - RDB + AOF for durability  
✅ **Batch Operations** - Prefetch multiple items  
✅ **Cache Invalidation** - Clear by prefix or pattern  
✅ **Performance Stats** - Monitor cache usage  

### Cache Prefixes

The caching service uses organized prefixes for different content types:

```python
PREFIX_STATIC = "static:"          # Static file assets
PREFIX_API_RESPONSE = "api_response:"  # API endpoint responses
PREFIX_CONFIG = "config:"          # Configuration data
PREFIX_VOCABULARY = "vocabulary:"  # Vocabulary data
PREFIX_LANGUAGE_LIST = "languages:"  # Language lists
```

### TTL Configuration

Default time-to-live values (in seconds):

```python
DEFAULT_TTL_STATIC = 86400 * 7     # 7 days for static assets
DEFAULT_TTL_API = 3600              # 1 hour for API responses
DEFAULT_TTL_CONFIG = 86400          # 1 day for configuration
```

Adjust in `app/services/static_cache_service.py`:
```python
class StaticContentCacheService:
    DEFAULT_TTL_STATIC = 86400 * 7  # Change this
    DEFAULT_TTL_API = 3600           # Or this
```

### Redis Configuration in Docker Compose

The Redis service is configured with:

```yaml
redis:
  image: redis:7
  command:
    - "redis-server"
    - "--maxmemory"
    - "512mb"                    # Max memory limit
    - "--maxmemory-policy"
    - "allkeys-lru"              # LRU eviction when full
    - "--save"
    - "60 1000"                  # RDB: save every 60s if 1000 keys changed
    - "--appendonly"
    - "yes"                      # AOF: durability log
    - "--appendfsync"
    - "everysec"                 # Fsync every second
  volumes:
    - redis_data:/data           # Persistent storage
```

**Memory Management:**
- **Max Memory:** 512 MB (adjust in production)
- **Eviction Policy:** `allkeys-lru` (remove least recently used)
- **Persistence:** RDB snapshots + AOF log

### API Endpoints for Cache Management

**Get Cache Statistics:**
```bash
curl -X GET http://localhost:8000/api/v1/management/cache/stats \
  -H "Authorization: Bearer {admin_token}"
```

Response:
```json
{
  "db_size_entries": 1250,
  "memory_used_bytes": 52428800,
  "memory_used_human": "50.00M",
  "memory_peak_bytes": 62914560,
  "memory_peak_human": "60.00M",
  "evicted_keys": 15
}
```

**Clear All Cache:**
```bash
curl -X DELETE http://localhost:8000/api/v1/management/cache/clear \
  -H "Authorization: Bearer {admin_token}"
```

**Clear Cache by Prefix:**
```bash
# Clear all API response cache
curl -X DELETE "http://localhost:8000/api/v1/management/cache/clear/api_response:" \
  -H "Authorization: Bearer {admin_token}"

# Clear vocabulary cache
curl -X DELETE "http://localhost:8000/api/v1/management/cache/clear/vocabulary:" \
  -H "Authorization: Bearer {admin_token}"
```

Supported prefixes: `static:`, `api_response:`, `config:`, `vocabulary:`, `languages:`

**Prefetch Languages:**
```bash
curl -X POST http://localhost:8000/api/v1/management/cache/prefetch/languages \
  -H "Authorization: Bearer {admin_token}"
```

**Check Cache Health:**
```bash
curl -X GET http://localhost:8000/api/v1/management/health/cache
```

### Usage in Code

#### 1. Basic Cache Operations

```python
from app.services.static_cache_service import StaticContentCacheService
from app.core.redis_client import get_redis_client

# Initialize service
redis_client = await get_redis_client()
cache_service = StaticContentCacheService(redis_client)

# Set cache
await cache_service.set_cache(
    key="languages_list",
    value=[{"code": "en", "name": "English"}],
    ttl=3600,
    prefix="languages:"
)

# Get from cache
languages = await cache_service.get_cache("languages_list", prefix="languages:")

# Delete cache
await cache_service.delete_cache("languages_list", prefix="languages:")
```

#### 2. Cache API Responses

```python
from fastapi import FastAPI, Depends

@app.get("/languages")
async def get_languages(
    cache_service: StaticContentCacheService = Depends(get_cache_service)
):
    # Try to get from cache
    cached = await cache_service.get_cached_language_list()
    if cached:
        return cached
    
    # Fetch from database
    languages = db.query(Language).all()
    
    # Cache it
    await cache_service.cache_language_list(languages)
    
    return languages
```

#### 3. Using Cache Decorator

```python
from app.services.static_cache_service import cache_response

@app.get("/config")
@cache_response(ttl=86400)
async def get_config(cache_service: StaticContentCacheService):
    # Automatically cached for 1 day
    return {"feature_flags": {...}}
```

#### 4. Batch Prefetch

```python
# Prefetch multiple items at once
content_to_cache = {
    "language1": {"code": "en", "name": "English"},
    "language2": {"code": "vi", "name": "Tiếng Việt"},
    "language3": {"code": "zh", "name": "中文"},
}

count = await cache_service.prefetch_static_content(
    content_map=content_to_cache,
    prefix="languages:",
    ttl=604800  # 7 days
)
print(f"Prefetched {count} items")
```

### Integration Patterns

#### Pattern 1: Cache-Aside (Lazy Loading)

```python
async def get_vocabulary(vocab_id: str):
    # Check cache first
    cached = await cache_service.get_cached_vocabulary(vocab_id)
    if cached:
        return cached
    
    # Load from database
    vocab = await db.get_vocabulary(vocab_id)
    
    # Cache for next time
    if vocab:
        await cache_service.cache_vocabulary(vocab_id, vocab)
    
    return vocab
```

#### Pattern 2: Cache-Through (Write-Through)

```python
async def update_vocabulary(vocab_id: str, data: dict):
    # Update database
    vocab = await db.update_vocabulary(vocab_id, data)
    
    # Update cache
    await cache_service.cache_vocabulary(vocab_id, vocab)
    
    return vocab
```

#### Pattern 3: Refresh-Ahead (Proactive Refresh)

```python
# In a background job or startup
async def prefetch_static_content():
    # Load critical data that's frequently accessed
    languages = await db.get_all_languages()
    await cache_service.cache_language_list(languages)
    
    # Load popular vocabularies
    popular_vocab = await db.get_popular_vocabularies(limit=100)
    for vocab in popular_vocab:
        await cache_service.cache_vocabulary(vocab.id, vocab.to_dict())
```

### Monitoring Cache Performance

**Key Metrics:**

```bash
# Cache hit ratio: indicates cache effectiveness
# Expected: >80% for frequently accessed data

# Memory usage: monitor for leaks or excessive growth
# Alert threshold: >80% of max memory

# Evicted keys: indicates cache is full and old items removed
# Acceptable: few evictions, many = increase Redis memory
```

**Redis CLI Monitoring:**

```bash
# Enter Redis container
docker-compose exec redis redis-cli

# Monitor in real-time
> MONITOR

# Get memory stats
> INFO memory

# Get key statistics
> DBSIZE
> KEYS *
> KEYS "api_response:*"

# Check eviction stats
> INFO stats | grep evicted_keys
```

---

## 🚀 Getting Started

### 1. Start Services with Docker Compose

```bash
cd /path/to/TranslationAppFlutter

# Start all services
docker-compose up -d

# Verify services are running
docker-compose ps

# Check logs
docker-compose logs -f backend
```

### 2. Verify Backup System

```bash
# Check backup service health
curl -X GET http://localhost:8000/api/v1/management/health/backup

# View logs
docker-compose logs backend | grep -i backup
```

### 3. Verify Cache System

```bash
# Check cache health
curl -X GET http://localhost:8000/api/v1/management/health/cache

# Get cache statistics
curl -X GET http://localhost:8000/api/v1/management/cache/stats \
  -H "Authorization: Bearer {admin_token}"
```

### 4. Create First Backup

```bash
# Trigger immediate backup
curl -X POST http://localhost:8000/api/v1/management/backups/create \
  -H "Authorization: Bearer {admin_token}"

# List backups
curl -X GET http://localhost:8000/api/v1/management/backups/list \
  -H "Authorization: Bearer {admin_token}"
```

### 5. Prefetch Static Content

```bash
# Prefetch languages
curl -X POST http://localhost:8000/api/v1/management/cache/prefetch/languages \
  -H "Authorization: Bearer {admin_token}"

# Verify cache has data
curl -X GET http://localhost:8000/api/v1/management/cache/stats \
  -H "Authorization: Bearer {admin_token}"
```

---

## 🔧 Production Configuration

### Redis for Production

```yaml
redis:
  image: redis:7
  command:
    - "redis-server"
    - "--maxmemory"
    - "2gb"                     # Increase for production
    - "--maxmemory-policy"
    - "allkeys-lru"
    - "--save"
    - "60 1000"
    - "--appendonly"
    - "yes"
    - "--appendfsync"
    - "everysec"
  volumes:
    - redis_data:/data
  restart: always
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Backup Strategy for Production

**Daily Schedule:**
- **2:00 AM:** Automated daily backup
- **Keep:** Last 7 days of backups
- **Storage:** Persistent Docker volume
- **Offsite:** Consider uploading to S3/GCS

**Backup Rotation:**
```bash
# In production cron job
0 3 * * 1 /scripts/backup-to-s3.sh  # Weekly backup to S3
```

### Monitoring & Alerts

**Set up alerts for:**
1. ❌ Backup failures
2. ⚠️ Redis memory usage > 80%
3. 🔴 Cache hit ratio < 50%
4. 📉 Evicted keys increasing rapidly

---

## 📚 File References

### Service Files
- [Backup Service](../app/services/backup_service.py)
- [Cache Service](../app/services/static_cache_service.py)
- [Management Endpoints](../app/api/v1/endpoints/management.py)

### Configuration Files
- [Requirements](../requirements.txt) - APScheduler added
- [Docker Compose](../docker-compose.yml) - Redis & backup volumes configured
- [Main App](../app/main.py) - Scheduler initialization

### Dependencies
- [app/core/redis_client.py](../app/core/redis_client.py) - Redis connection
- [app/core/config.py](../app/core/config.py) - Configuration

---

## 🐛 Troubleshooting

### Backup Issues

**Problem:** "pg_dump not found"
```
Solution: PostgreSQL client tools must be installed in backend container
Dockerfile should include: apt-get install postgresql-client
```

**Problem:** "Permission denied" on backup directory
```
Solution: Check volume permissions in Docker:
docker-compose exec backend ls -la /backups/
```

**Problem:** Backup scheduler not running
```
Solution: Check logs for APScheduler initialization:
docker-compose logs backend | grep -i "scheduler\|apscheduler"
```

### Cache Issues

**Problem:** Redis connection failed
```
Solution: Verify Redis is running:
docker-compose ps redis
docker-compose logs redis
```

**Problem:** Cache memory full, keys being evicted
```
Solution: Increase Redis max memory in docker-compose.yml:
- "--maxmemory"
- "2gb"  # Increase this value
```

**Problem:** Cache hit ratio too low
```
Solution: 
1. Check TTL values are appropriate
2. Verify cache service initialization in main.py
3. Monitor cache statistics
curl http://localhost:8000/api/v1/management/cache/stats
```

### Database After Restoration

**After restoring a backup:**
1. Verify data integrity
2. Run any pending migrations
3. Clear API response cache
4. Refresh connected clients

```bash
# Clear cache after restoration
curl -X DELETE http://localhost:8000/api/v1/management/cache/clear \
  -H "Authorization: Bearer {admin_token}"

# Run migrations if needed
alembic upgrade head
```

---

## 📞 Support

For issues or questions:
1. Check service logs: `docker-compose logs {service_name}`
2. Review health endpoints: `/api/v1/management/health/backup` and `/cache`
3. Check backup directory: `docker-compose exec backend ls -la /backups/database/`
4. Monitor Redis: `docker-compose exec redis redis-cli INFO`

---

**Last Updated:** May 17, 2026  
**Version:** 1.0.0
