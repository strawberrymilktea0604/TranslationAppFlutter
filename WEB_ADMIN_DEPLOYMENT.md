# Web Admin Dashboard Deployment Guide

**Status:** ✅ Ready for Production  
**Last Updated:** May 24, 2026  
**Environment:** Docker + Nginx + Flutter Web

---

## 📋 Checklist Deployment

### ✅ Pre-Deployment Requirements

- [ ] Flutter SDK 3.10.7+ installed
- [ ] Docker & Docker Compose installed
- [ ] Backend codebase built and tested
- [ ] Database migrations completed (`alembic upgrade head`)
- [ ] All environment variables configured in `.env`
- [ ] Admin user account created in database
- [ ] SSL/TLS certificate ready (for production)

---

## 🏗️ Build & Deployment Steps

### Step 1: Build Flutter Web Admin Dashboard

```bash
cd frontend

# Option A: Development build (faster, larger bundle)
flutter build web --target=lib/main_web.dart --web-renderer html --release

# Option B: Production build (slower, optimized, CanvasKit - RECOMMENDED)
flutter build web \
  --target=lib/main_web.dart \
  --web-renderer canvaskit \
  --release \
  --dart-define=FLUTTER_WEB_USE_EXPERIMENTAL_CANVAS_TEXT=true
```

**Output:** Static files generated to `frontend/build/web/`

✅ **Verify build:**
```bash
ls -la frontend/build/web/
# Should show: index.html, main.dart.js, assets/, etc.
```

### Step 2: Configure Environment Variables

```bash
# Copy example configuration
cp backend/.env.web.example backend/.env

# Edit for your deployment
nano backend/.env  # or use your editor

# CRITICAL SETTINGS FOR WEB ADMIN:
export ENVIRONMENT="production"
export SECRET_KEY="your-32-char-production-secret-key"
export DATABASE_URL="postgresql+asyncpg://user:pass@db-host:5432/translation_app"
export REDIS_URL="redis://redis-host:6379/0"
export BACKEND_CORS_ORIGINS="https://admin.yourdomain.com,http://localhost:8080"
export ADMIN_DASHBOARD_ENABLED=true
```

### Step 3: Start Docker Services

```bash
# Build and start all services
docker-compose up -d

# Check service status
docker-compose ps

# Verify services are healthy
docker-compose ps --format "table {{.Service}}\t{{.Status}}"
```

**Expected Status:**
```
NAME              STATUS
db                Up (healthy)
redis             Up (healthy)
log_aggregator    Up
backend           Up (healthy)
nginx             Up (healthy)
```

### Step 4: Run Database Migrations

```bash
# Apply all pending migrations
docker-compose exec backend alembic upgrade head

# Verify migrations
docker-compose exec backend alembic current
```

### Step 5: Verify Backend API Health

```bash
# Check backend health
curl http://localhost:8000/health

# Expected response:
# {
#   "status": "ok",
#   "environment": "production",
#   "project": "TranslationApp API - Web Admin",
#   "redis": "ok"
# }

# Check admin-specific endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8000/api/v1/admin/health

# Check Nginx health
curl http://localhost:8080/health
```

### Step 6: Access Web Admin Dashboard

```
Frontend: http://localhost:8080/admin
API Docs: http://localhost:8080/docs
Health Check: http://localhost:8080/health
```

---

## 🔐 Admin Authentication & Access Control

### Create Admin User (One-time Setup)

```bash
# Connect to database
docker-compose exec db psql -U postgres -d translation_app

# SQL to create admin user
INSERT INTO "user" (
  email, 
  hashed_password, 
  first_name, 
  last_name, 
  role, 
  is_active
) VALUES (
  'admin@example.com',
  'hashed_bcrypt_password_here',
  'Admin',
  'User',
  'admin',
  true
);
```

Or use the backend API (if user registration enabled):

```bash
# Register admin account
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "securepassword123",
    "first_name": "Admin",
    "last_name": "User"
  }'

# Then promote to admin (via database or admin API)
```

### Login to Dashboard

1. Navigate to: `http://localhost:8080/admin`
2. Enter admin credentials
3. Verify 2FA if enabled (configure in `.env`: `ADMIN_REQUIRE_2FA=true`)
4. Access admin features:
   - 👥 User Management
   - 📊 Analytics & Statistics
   - 🔧 System Settings
   - 📋 Translation Logs
   - 🔐 Security & Audit Logs

---

## 🔍 Connection Verification Checklist

### ✅ Web Admin → Backend API

```bash
# 1. Check CORS configuration
curl -X OPTIONS http://localhost:8080/api/v1/health \
  -H "Origin: http://localhost:8080" \
  -H "Access-Control-Request-Method: GET" -v

# Expected: Access-Control-Allow-Origin: *

# 2. Check API connectivity from web admin
# (Open browser DevTools → Network tab while accessing dashboard)

# 3. Test with cURL
curl -X GET http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### ✅ Backend → Database

```bash
# Check database connectivity
docker-compose exec backend python -c \
  "import asyncio; from app.core.database import async_session_maker; \
   asyncio.run(async_session_maker())"

# OR check via health endpoint
curl http://localhost:8000/api/v1/health
```

### ✅ Backend → Redis

```bash
# Check Redis connectivity
docker-compose exec redis redis-cli ping
# Expected: PONG

# Check from backend
docker-compose exec backend redis-cli -h redis ping
```

### ✅ Nginx → Backend

```bash
# Check Nginx logs for errors
docker-compose logs nginx

# Test Nginx routing
curl -v http://localhost:8080/api/v1/health
# Check: Server: nginx/alpine
```

---

## 📊 Performance & Monitoring

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f nginx
docker-compose logs -f backend
docker-compose logs -f db

# With JSON logging
docker-compose logs -f backend | grep "level.*ERROR"
```

### Monitor Resources

```bash
# Docker resource usage
docker stats

# Database performance
docker-compose exec db psql -U postgres -d translation_app -c \
  "SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"

# Redis memory usage
docker-compose exec redis redis-cli INFO memory
```

### Admin Dashboard Metrics

```bash
# Access analytics via API
curl -X GET http://localhost:8000/api/v1/admin/analytics \
  -H "Authorization: Bearer ADMIN_TOKEN"

# System health status
curl -X GET http://localhost:8000/api/v1/admin/health \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

---

## 🚀 Production Deployment (AWS/Cloud)

### Environment Variables for Production

```bash
# .env.production
ENVIRONMENT="production"
SECRET_KEY="use-aws-secrets-manager-or-vault"
DATABASE_URL="postgresql://user:pass@rds-endpoint:5432/translation_app"
REDIS_URL="redis://elasticache-endpoint:6379/0"
BACKEND_CORS_ORIGINS="https://admin.yourdomain.com"
ADMIN_DASHBOARD_ENABLED=true
ADMIN_REQUIRE_2FA=true
BACKUP_ENABLED=true
```

### SSL/TLS Setup with Nginx

Update `nginx.conf`:

```nginx
server {
    listen 443 ssl http2;
    server_name admin.yourdomain.com;

    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;
    
    # Modern configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Rest of configuration...
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name admin.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

### Docker Production Stack

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./frontend/build/web:/var/www/admin:ro
      - /etc/letsencrypt/:/etc/nginx/certs/:ro
    # ... rest of config
```

### Deploy Command

```bash
# Production deployment
docker-compose -f docker-compose.prod.yml up -d

# Verify deployment
docker-compose -f docker-compose.prod.yml exec backend alembic upgrade head
curl https://admin.yourdomain.com/health
```

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| **Admin dashboard not loading** | Check nginx logs: `docker-compose logs nginx` |
| **API 401 Unauthorized** | Verify `SECRET_KEY` matches backend config |
| **CORS errors in console** | Update `BACKEND_CORS_ORIGINS` in `.env` |
| **Database connection failed** | Check `DATABASE_URL` and container network |
| **Redis unavailable** | Ensure Redis container is running: `docker-compose ps` |
| **Slow dashboard load** | Check network tab in DevTools; optimize Flutter bundle |
| **Admin features not visible** | Verify admin role in database; check feature flags |

### Emergency Commands

```bash
# Restart all services
docker-compose restart

# Force rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Check all health endpoints
curl http://localhost:8080/health && \
curl http://localhost:8000/health && \
docker-compose ps

# Database backup before deployment
docker-compose exec backend \
  python -m app.scripts.backup_database
```

---

## 📝 Next Steps

1. **Configure Monitoring:** Set up Prometheus + Grafana for metrics
2. **Enable 2FA:** Configure Two-Factor Authentication for admins
3. **Set up Alerts:** Implement email/Slack alerts for critical errors
4. **SSL Certificate:** Install proper SSL certificate (Let's Encrypt recommended)
5. **Backup Strategy:** Configure automated daily backups with retention policy
6. **Performance:** Enable caching, CDN, and optimize asset delivery

---

## 📞 Support & Documentation

- Backend API Docs: `http://localhost:8080/docs`
- Admin Features: Check `ADMIN_FEATURES_ENABLED` in `.env`
- Logs: `docker-compose logs -f backend`
- Health Status: `curl http://localhost:8080/health`

