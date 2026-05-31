# Backup & Cache Configuration

## Database Backup Configuration

Update these settings in `app/main.py` during backup scheduler initialization:

```python
# Current defaults
backup_service = DatabaseBackupService(
    db_url=settings.DATABASE_URL,
    backup_dir="/backups/database",      # Backup storage location
    max_backups=7,                        # Number of backups to keep
    compress=True,                        # Compress backups with gzip
)
```

### Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `db_url` | From `.env` | PostgreSQL connection string |
| `backup_dir` | `/backups/database` | Where backups are stored |
| `max_backups` | `7` | How many backups to keep (older deleted) |
| `compress` | `True` | Whether to gzip compress backups |

### Backup Schedule

Current schedule: **Daily at 2:00 AM**

Change in `app/services/backup_service.py`:

```python
def initialize_scheduler(self):
    # Current: Every day at 2:00 AM
    self.scheduler.add_job(
        self.backup_service.create_backup,
        trigger=CronTrigger(hour=2, minute=0),
        id="daily_backup",
        name="Daily Database Backup",
        replace_existing=True,
    )
```

**Other schedule options:**

```python
# Every 6 hours
trigger=CronTrigger(hour='*/6')

# Every day at 3:00 AM
trigger=CronTrigger(hour=3, minute=0)

# Every Sunday at 1:00 AM
trigger=CronTrigger(day_of_week='sun', hour=1, minute=0)

# Every hour at :30 minutes
trigger=CronTrigger(minute=30)
```

---

## Redis Cache Configuration

### Memory Configuration

Update in `docker-compose.yml`:

```yaml
redis:
  command:
    - "redis-server"
    - "--maxmemory"
    - "512mb"                    # Change this for your needs
    - "--maxmemory-policy"
    - "allkeys-lru"              # Eviction policy
```

**Memory Sizing Guide:**

| Environment | Recommended | Use Case |
|------------|-------------|----------|
| Development | 256-512 MB | Local testing |
| Staging | 1-2 GB | Pre-production testing |
| Production | 2-8 GB | Based on data volume |

**Eviction Policies:**

- `allkeys-lru` - Remove least recently used (default, recommended)
- `volatile-lru` - Remove LRU from keys with TTL
- `allkeys-random` - Remove random keys
- `noeviction` - Reject writes when full (not recommended)

### Persistence Configuration

```yaml
redis:
  command:
    - "--save"           # RDB snapshots
    - "60 1000"          # Save if 1000 keys changed in 60 seconds
    - "--appendonly"     # AOF for durability
    - "yes"
    - "--appendfsync"    # How often to fsync AOF
    - "everysec"         # Options: always, everysec, no
```

**Persistence Options:**

| Mode | Speed | Durability | Recovery |
|------|-------|-----------|----------|
| RDB only | Fast | Low | Good |
| AOF only | Slow | High | Exact |
| Both | Medium | High | Best |
| None | Fastest | None | None |

### Cache TTL Configuration

Update in `app/services/static_cache_service.py`:

```python
class StaticContentCacheService:
    DEFAULT_TTL_STATIC = 86400 * 7      # 7 days (604800 seconds)
    DEFAULT_TTL_API = 3600               # 1 hour (3600 seconds)
    DEFAULT_TTL_CONFIG = 86400           # 1 day (86400 seconds)
```

**Common TTL Values (in seconds):**

| Duration | Seconds | Usage |
|----------|---------|-------|
| 1 minute | 60 | Rapidly changing data |
| 5 minutes | 300 | Real-time leaderboards |
| 15 minutes | 900 | API responses |
| 1 hour | 3600 | User preferences |
| 1 day | 86400 | Configuration |
| 7 days | 604800 | Static assets |
| 30 days | 2592000 | Long-term cache |

### Cache Prefix Customization

Add custom prefixes in `static_cache_service.py`:

```python
class StaticContentCacheService:
    PREFIX_STATIC = "static:"
    PREFIX_API_RESPONSE = "api_response:"
    PREFIX_CONFIG = "config:"
    PREFIX_VOCABULARY = "vocabulary:"
    PREFIX_LANGUAGE_LIST = "languages:"
    PREFIX_CUSTOM = "custom:"  # Add your own
```

---

## Environment Variables

Add to `backend/.env`:

```env
# Backup Configuration
BACKUP_DIR=/backups/database
MAX_BACKUPS=7
BACKUP_COMPRESSION=true
BACKUP_SCHEDULE_HOUR=2
BACKUP_SCHEDULE_MINUTE=0

# Redis Configuration
REDIS_MAX_MEMORY=512mb
REDIS_EVICTION_POLICY=allkeys-lru
REDIS_PERSISTENCE=true

# Cache TTL Configuration
CACHE_TTL_STATIC=604800
CACHE_TTL_API=3600
CACHE_TTL_CONFIG=86400
```

Then use in code:

```python
# In app/services/backup_service.py
backup_service = DatabaseBackupService(
    db_url=settings.DATABASE_URL,
    backup_dir=os.getenv("BACKUP_DIR", "/backups/database"),
    max_backups=int(os.getenv("MAX_BACKUPS", 7)),
    compress=os.getenv("BACKUP_COMPRESSION", "true").lower() == "true",
)

# In app/services/static_cache_service.py
DEFAULT_TTL_STATIC = int(os.getenv("CACHE_TTL_STATIC", 604800))
DEFAULT_TTL_API = int(os.getenv("CACHE_TTL_API", 3600))
DEFAULT_TTL_CONFIG = int(os.getenv("CACHE_TTL_CONFIG", 86400))
```

---

## Production Configuration

### High-Traffic Production

```yaml
# docker-compose.yml
redis:
  image: redis:7
  command:
    - "redis-server"
    - "--maxmemory"
    - "4gb"                      # Increase for high traffic
    - "--maxmemory-policy"
    - "allkeys-lru"
    - "--save"
    - "60 10000"                 # More aggressive saves
    - "--appendonly"
    - "yes"
    - "--appendfsync"
    - "everysec"
    - "--databases"
    - "2"                        # One for cache, one for sessions
  deploy:
    resources:
      limits:
        cpus: '2.0'              # Allocate more CPU
        memory: 5G                # More than Redis max
```

### Backup Strategy

```python
# Production backups - more frequent
self.scheduler.add_job(
    self.backup_service.create_backup,
    trigger=CronTrigger(hour='*/6'),    # Every 6 hours
    id="production_backup",
)

# Keep more backups in production
backup_service = DatabaseBackupService(
    db_url=settings.DATABASE_URL,
    max_backups=30,              # Keep 30 backups (monthly)
    compress=True,
)
```

### Failover Configuration

For redundancy, consider:

1. **Redis Sentinel** - Automatic failover
2. **Redis Cluster** - Distributed cache
3. **Backup S3 Upload** - Offsite storage
4. **Replication** - Cross-region backup

---

## Monitoring & Alerts

### Key Metrics to Monitor

1. **Backup Size Growth**
   - Alert if backup size > 2x average
   - Indicates data explosion or anomaly

2. **Cache Hit Ratio**
   - Target: > 80%
   - Alert if < 50%

3. **Redis Memory**
   - Alert if > 80% of max
   - Alert if evictions > 100/min

4. **Backup Failures**
   - Alert on any failure
   - Check logs immediately

### Prometheus Metrics

```python
# Add to app/main.py
from prometheus_client import Counter, Gauge, Histogram

backup_count = Counter('backups_created_total', 'Total backups created')
backup_size = Gauge('backup_size_bytes', 'Size of last backup')
cache_hits = Counter('cache_hits_total', 'Total cache hits')
cache_misses = Counter('cache_misses_total', 'Total cache misses')
redis_memory = Gauge('redis_memory_bytes', 'Redis memory usage')
```

---

## Performance Tuning

### For Better Backup Performance

```python
# Use faster compression
compress=True  # Default gzip

# Or disable for very large databases
compress=False  # Then handle externally
```

### For Better Cache Performance

```python
# Warm cache on startup
async def prefetch_on_startup():
    # Load frequently accessed data
    languages = await db.get_all_languages()
    await cache_service.cache_language_list(languages)

# In app/main.py startup
@asynccontextmanager
async def lifespan(app: FastAPI):
    # ... existing code ...
    await prefetch_on_startup()
    yield
```

### For Large Databases

```yaml
# Increase PostgreSQL backup connections
postgres:
  environment:
    POSTGRES_INITDB_ARGS: "-c max_wal_senders=10"

# Increase pg_dump workers (if supported)
pg_dump -j 4  # 4 parallel workers
```

---

## Testing Configurations

### Development

```yaml
# Minimal resources
redis:
  command:
    - "redis-server"
    - "--maxmemory"
    - "256mb"
    - "--save"
    - ""           # Disable persistence
    - "--appendonly"
    - "no"
```

### Testing

```python
# Test configuration
TEST_REDIS_URL = "redis://localhost:6380/1"  # Separate instance
TEST_BACKUP_DIR = "/tmp/test_backups"
TEST_MAX_BACKUPS = 2
```

### CI/CD

```bash
# In your CI pipeline
docker-compose -f docker-compose.test.yml up -d

# Run tests
pytest backend/tests/

# Verify backup functionality
python -m pytest backend/tests/test_backup_service.py -v

# Verify cache functionality
python -m pytest backend/tests/test_cache_service.py -v
```

---

## Configuration Checklist

- [ ] Redis memory size matches your needs
- [ ] Backup retention policy is appropriate
- [ ] Backup schedule fits your maintenance window
- [ ] Cache TTLs are tuned for your data
- [ ] Persistence options match your durability needs
- [ ] Monitoring/alerts are configured
- [ ] Disaster recovery plan includes backup testing
- [ ] Team knows how to restore from backup
- [ ] Storage capacity planned for backups

---

**Configuration Version:** 1.0.0  
**Last Updated:** May 17, 2026
