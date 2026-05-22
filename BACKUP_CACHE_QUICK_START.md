# Backup & Cache Quick Start Guide

## ⚡ 5-Minute Setup

### Prerequisites
- Docker and Docker Compose running
- Admin API token for management endpoints

### Step 1: Start Services

```bash
cd /path/to/TranslationAppFlutter
docker-compose up -d
docker-compose logs -f backend  # Watch startup logs
```

Wait for: `✅ Database backup scheduler initialized and started`

### Step 2: Get Your Admin Token

```bash
# Create admin user or login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password"}'
```

Extract `access_token` from response and save as `TOKEN`:
```bash
TOKEN="your_admin_token_here"
```

---

## 📦 Backup Commands

### Create Backup Now
```bash
curl -X POST http://localhost:8000/api/v1/management/backups/create \
  -H "Authorization: Bearer $TOKEN"
```

### List All Backups
```bash
curl -X GET http://localhost:8000/api/v1/management/backups/list \
  -H "Authorization: Bearer $TOKEN"
```

### Restore Backup
⚠️ **WARNING: Overwrites current database!**
```bash
curl -X POST http://localhost:8000/api/v1/management/backups/backup_20260517_020000.sql.gz/restore \
  -H "Authorization: Bearer $TOKEN"
```

### Delete Old Backup
```bash
curl -X DELETE http://localhost:8000/api/v1/management/backups/backup_20260517_020000.sql.gz \
  -H "Authorization: Bearer $TOKEN"
```

### Check Backup Health
```bash
curl -X GET http://localhost:8000/api/v1/management/health/backup
```

---

## 🚀 Cache Commands

### Get Cache Statistics
```bash
curl -X GET http://localhost:8000/api/v1/management/cache/stats \
  -H "Authorization: Bearer $TOKEN"
```

### Clear All Cache
```bash
curl -X DELETE http://localhost:8000/api/v1/management/cache/clear \
  -H "Authorization: Bearer $TOKEN"
```

### Clear Specific Cache Type
```bash
# API responses
curl -X DELETE "http://localhost:8000/api/v1/management/cache/clear/api_response:" \
  -H "Authorization: Bearer $TOKEN"

# Vocabulary
curl -X DELETE "http://localhost:8000/api/v1/management/cache/clear/vocabulary:" \
  -H "Authorization: Bearer $TOKEN"

# Languages
curl -X DELETE "http://localhost:8000/api/v1/management/cache/clear/languages:" \
  -H "Authorization: Bearer $TOKEN"
```

### Prefetch Languages
```bash
curl -X POST http://localhost:8000/api/v1/management/cache/prefetch/languages \
  -H "Authorization: Bearer $TOKEN"
```

### Check Cache Health
```bash
curl -X GET http://localhost:8000/api/v1/management/health/cache
```

---

## 🐳 Docker Commands

### View Backup Directory
```bash
docker-compose exec backend ls -lah /backups/database/
```

### Access Redis CLI
```bash
docker-compose exec redis redis-cli
# Inside Redis CLI:
> DBSIZE                    # Number of keys
> INFO memory               # Memory stats
> KEYS "api_response:*"     # View API cache keys
> MONITOR                   # Watch operations in real-time
> EXIT                      # Exit CLI
```

### View Service Logs
```bash
# Backend
docker-compose logs -f backend

# Redis
docker-compose logs -f redis

# Database
docker-compose logs -f db
```

### Restart Services
```bash
# Restart backend (preserves data)
docker-compose restart backend

# Full reset (removes volumes!)
docker-compose down -v
docker-compose up -d
```

---

## 📊 Monitoring

### Check All Systems
```bash
echo "=== Backup System ==="
curl -s http://localhost:8000/api/v1/management/health/backup | jq .

echo -e "\n=== Cache System ==="
curl -s http://localhost:8000/api/v1/management/health/cache | jq .

echo -e "\n=== App Health ==="
curl -s http://localhost:8000/health | jq .
```

### Real-time Redis Monitoring
```bash
watch -n 1 'docker-compose exec redis redis-cli INFO memory'
```

### Backup Progress
```bash
watch -n 2 'docker-compose exec backend ls -lh /backups/database/'
```

---

## 🔧 Common Operations

### After Database Restore
```bash
# 1. Restore backup
curl -X POST "http://localhost:8000/api/v1/management/backups/{backup_file}/restore" \
  -H "Authorization: Bearer $TOKEN"

# 2. Wait for completion (monitor logs)
docker-compose logs -f backend

# 3. Clear cache
curl -X DELETE http://localhost:8000/api/v1/management/cache/clear \
  -H "Authorization: Bearer $TOKEN"

# 4. Verify
curl http://localhost:8000/health
```

### Pre-Deployment Backup
```bash
# 1. Create backup with name
curl -X POST "http://localhost:8000/api/v1/management/backups/create?backup_name=before_deploy_$(date +%Y%m%d)" \
  -H "Authorization: Bearer $TOKEN"

# 2. Wait for completion
docker-compose logs backend | grep "✅ Backup created"

# 3. Deploy
# ... your deployment commands ...

# 4. If issues, restore
curl -X POST "http://localhost:8000/api/v1/management/backups/backup_before_deploy_{date}/restore" \
  -H "Authorization: Bearer $TOKEN"
```

### Cache Warming on Startup
```bash
# Prefetch all static content
curl -X POST http://localhost:8000/api/v1/management/cache/prefetch/languages \
  -H "Authorization: Bearer $TOKEN"

# Add more if needed...
```

---

## 🚨 Troubleshooting

### No Backups Showing
```bash
# Check backup directory exists
docker-compose exec backend ls /backups/database/

# Check logs
docker-compose logs backend | grep -i backup

# Verify pg_dump is available
docker-compose exec backend which pg_dump
```

### Redis Not Responding
```bash
# Check if running
docker-compose ps redis

# Check logs
docker-compose logs redis

# Restart Redis
docker-compose restart redis
```

### High Memory Usage
```bash
# Check current usage
docker-compose exec redis redis-cli INFO memory

# Clear cache
curl -X DELETE http://localhost:8000/api/v1/management/cache/clear \
  -H "Authorization: Bearer $TOKEN"

# Check evictions
docker-compose exec redis redis-cli INFO stats
```

---

## 📈 Performance Tips

1. **Backups:** Run during low-traffic hours (configured for 2 AM)
2. **Cache:** Warm cache on startup to reduce database load
3. **TTLs:** Adjust cache TTL based on data update frequency
4. **Memory:** Monitor Redis memory and increase if needed
5. **Retention:** Keep 7 days backups, export old ones to cold storage

---

## 🔗 Full Documentation

See [BACKUP_AND_CACHE_SETUP.md](BACKUP_AND_CACHE_SETUP.md) for complete documentation.

---

**Quick Reference Date:** May 17, 2026
