# Configuration Quick Reference

**Last Updated:** May 24, 2026  
**Quick Navigation Guide**

---

## 🚀 Quick Start Commands

### Build & Deploy Web Admin

```bash
# Build Flutter web
cd frontend
flutter build web --target=lib/main_web.dart --web-renderer canvaskit --release

# Start all services
docker-compose up -d

# Run migrations
docker-compose exec backend alembic upgrade head

# Access services
# Frontend: http://localhost:8080/admin
# API Docs: http://localhost:8080/docs
# Health: http://localhost:8080/health
```

### Development Setup

```bash
# Setup development environment
cp backend/.env.example backend/.env

# Edit .env for your setup
nano backend/.env

# Start services
docker-compose up -d

# Check health
curl http://localhost:8080/health
```

---

## 📋 Environment Variables Cheat Sheet

### Essential Settings

```bash
# Application
ENVIRONMENT=production|staging|development
SECRET_KEY=your-32-char-secret-key

# Database
DATABASE_URL=postgresql+asyncpg://user:pass@host:5432/translation_app

# Redis (for tokens, rate limiting, sessions)
REDIS_URL=redis://host:6379/0

# API Server
API_V1_STR=/api/v1
BACKEND_CORS_ORIGINS=http://localhost:8080,https://yourdomain.com
```

### Rate Limiting

```bash
# Per-hour limits (default: guest=10, user=100, admin=1000)
GUEST_MAX_REQUESTS_PER_HOUR=10
USER_MAX_REQUESTS_PER_HOUR=100
ADMIN_MAX_REQUESTS_PER_HOUR=1000
PREMIUM_MAX_REQUESTS_PER_HOUR=500

# Character limits per request
GUEST_MAX_CHAR_LENGTH=500
USER_MAX_CHAR_LENGTH=5000
ADMIN_MAX_CHAR_LENGTH=50000

# Rate limit window (1 hour)
RATE_LIMIT_WINDOW_SECONDS=3600
```

### WebSocket

```bash
# Connection
WEBSOCKET_ENABLED=true
WEBSOCKET_PING_INTERVAL=30          # Keep-alive (seconds)
WEBSOCKET_CONNECTION_TIMEOUT=30      # Initial handshake
WEBSOCKET_MAX_CONNECTIONS_PER_USER=5

# Conversation (real-time voice translation)
CONVERSATION_SESSION_TIMEOUT=300     # 5 minutes idle
CONVERSATION_SEGMENT_TIMEOUT=10      # Utterance timeout
CONVERSATION_MAX_AUDIO_SIZE=50       # MB

# Audio Streaming
AUDIO_SAMPLE_RATE=16000              # Hz
AUDIO_CHANNELS=1                     # Mono
AUDIO_CHUNK_SIZE=4096                # Bytes per chunk
```

### Logging

```bash
# Log Level
LOG_LEVEL=INFO|DEBUG|WARNING|ERROR

# FluentD
FLUENTD_ENABLED=true
FLUENTD_HOST=log_aggregator
FLUENTD_PORT=24224

# Real-time Session Logging
REALTIME_SESSION_LOGGING_ENABLED=true
SESSION_LOG_RETENTION_DAYS=30
PERFORMANCE_METRICS_ENABLED=true
AUDIT_LOGGING_ENABLED=true
```

---

## 📁 Key Configuration Files

| File | Purpose | Edit For |
|------|---------|----------|
| `.env` | Application settings | Secrets, URLs, limits |
| `nginx.conf` | Reverse proxy routing | API routes, SSL, CORS |
| `docker-compose.yml` | Service orchestration | Ports, volumes, healthchecks |
| `backend/app/core/config.py` | Python config class | Default values, validation |

---

## 🔐 Admin Deployment Checklist

```bash
# 1. Build web admin
flutter build web --target=lib/main_web.dart --web-renderer canvaskit --release

# 2. Setup environment
cp backend/.env.web.example backend/.env
# Edit with production values

# 3. Start services
docker-compose up -d

# 4. Run migrations
docker-compose exec backend alembic upgrade head

# 5. Create admin user (via API or database)
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "securepassword",
    "first_name": "Admin",
    "last_name": "User"
  }'

# 6. Verify deployment
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/docs  # Swagger docs
```

---

## 🔌 WebSocket Client Implementation

### Flutter Web Client

```dart
// Connect to sync notifications
final channel = WebSocketChannel.connect(
  Uri.parse('ws://localhost:8080/api/v1/ws?token=$accessToken'),
);

channel.stream.listen((event) {
  if (jsonDecode(event)['event'] == 'sync_completed') {
    print('Sync complete!');
  }
});

// Send keepalive
Timer.periodic(Duration(seconds: 30), (_) {
  channel.sink.add(jsonEncode({'ping': true}));
});
```

### Web JavaScript Client

```javascript
const ws = new WebSocket(
  `ws://localhost:8080/api/v1/ws?token=${accessToken}`
);

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  if (data.event === 'sync_completed') {
    console.log('Synced:', data.synced_count);
  }
};
```

---

## 📊 Rate Limiting API

### Check Limits

```bash
# Get current rate limit status
curl -H "Authorization: Bearer TOKEN" \
  http://localhost:8000/api/v1/admin/rate-limits/user:123

# Response includes usage by request type (text, audio, image, etc.)
```

### Reset Limits (Admin)

```bash
# Reset all limits for user
curl -X POST \
  http://localhost:8000/api/v1/admin/rate-limits/user:123/reset \
  -H "Authorization: Bearer ADMIN_TOKEN"

# Reset specific type
curl -X POST \
  "http://localhost:8000/api/v1/admin/rate-limits/user:123/reset?type=audio" \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

---

## 🔍 Logging & Monitoring

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f nginx
docker-compose logs -f log_aggregator

# Session logs only
docker-compose logs -f backend | grep "session_id"

# Errors only
docker-compose logs -f backend | grep "ERROR"
```

### Query with jq

```bash
# Parse JSON logs
docker-compose logs backend | jq '.event_type' | sort | uniq -c

# Get STT latencies
docker-compose logs backend | grep "stt_completed" | jq '.latency_ms'

# Find slow translations
docker-compose logs backend | grep "translation_completed" | \
  jq 'select(.latency_ms > 3000)'
```

### Monitor Resources

```bash
# Docker resource usage
docker stats

# Database connections
docker-compose exec db psql -U postgres -d translation_app \
  -c "SELECT count(*) FROM pg_stat_activity;"

# Redis memory
docker-compose exec redis redis-cli INFO memory
```

---

## 🛡️ Security Settings

### Required Environment Variables (Never Leave Empty)

```bash
SECRET_KEY=generate-a-random-32-char-string-and-put-here
GOOGLE_CLOUD_API_KEY=your-gcp-api-key  # Optional but recommended
```

### CORS Security

```bash
# Development (allow all)
BACKEND_CORS_ORIGINS="*"

# Production (restrict to your domains)
BACKEND_CORS_ORIGINS="https://admin.yourdomain.com,https://app.yourdomain.com"
```

### Token Security

```bash
ACCESS_TOKEN_EXPIRE_MINUTES=15      # Short-lived
REFRESH_TOKEN_EXPIRE_DAYS=7         # Longer-lived
TOKEN_BLACKLIST_EXPIRY_MINUTES=1440 # 24 hours
```

---

## 🚨 Common Issues & Solutions

### "Rate limit exceeded"

```bash
# Check user's rate limit status
curl -H "Authorization: Bearer TOKEN" \
  http://localhost:8000/api/v1/admin/rate-limits/user:123

# Admin: Reset the limit
curl -X POST \
  http://localhost:8000/api/v1/admin/rate-limits/user:123/reset \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

### "WebSocket connection refused"

```bash
# Verify Nginx headers
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://localhost:8080/api/v1/ws?token=TOKEN

# Should return status 101 Switching Protocols
```

### "No logs appearing"

```bash
# Check FluentD is running
docker-compose ps log_aggregator

# Check backend is logging
docker-compose logs -f backend | head -20

# Verify log files exist
docker-compose exec log_aggregator ls -la /fluentd/log/
```

### "High latency"

```bash
# Check database performance
docker-compose exec db psql -U postgres -d translation_app \
  -c "SELECT now() - query_start AS duration, query FROM pg_stat_activity WHERE state='active';"

# Check Redis
docker-compose exec redis redis-cli INFO stats

# Monitor system resources
docker stats
```

---

## 🔗 Useful Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | System health check |
| `GET /api/v1/docs` | Swagger API documentation |
| `GET /api/v1/redoc` | ReDoc API documentation |
| `GET /api/v1/openapi.json` | OpenAPI specification |
| `POST /api/v1/auth/login` | User login |
| `POST /api/v1/auth/refresh` | Refresh access token |
| `POST /api/v1/auth/logout` | Logout and revoke token |
| `GET /api/v1/admin/users` | List users (admin only) |
| `GET /api/v1/admin/rate-limits/{id}` | Check rate limits (admin) |
| `WS /api/v1/ws` | Sync notifications (WebSocket) |
| `WS /api/v1/ws/conversation` | Real-time voice translation (WebSocket) |

---

## 📞 Documentation Links

- [WEB_ADMIN_DEPLOYMENT.md](WEB_ADMIN_DEPLOYMENT.md) - Full deployment guide
- [AI_API_RATE_LIMITING.md](AI_API_RATE_LIMITING.md) - Rate limiting details
- [WEBSOCKET_CONFIGURATION.md](WEBSOCKET_CONFIGURATION.md) - WebSocket setup
- [REALTIME_SESSION_LOGGING.md](REALTIME_SESSION_LOGGING.md) - Logging details
- [CONFIGURATION_IMPLEMENTATION_SUMMARY.md](CONFIGURATION_IMPLEMENTATION_SUMMARY.md) - Complete summary
- [AGENTS.md](AGENTS.md) - Project setup guidelines

---

## 🎯 Next: Choose Your Deployment Path

### Path A: Development (All-in-Docker)
1. `cp backend/.env.example backend/.env`
2. Keep default DATABASE_URL `@db:5432` and REDIS_URL `redis:6379`
3. `docker-compose up -d`
4. Done! 🎉

### Path B: Hybrid (Backend on Host)
1. `cp backend/.env.example backend/.env`
2. Change DATABASE_URL to `@localhost:5433`
3. Change REDIS_URL to `localhost:6379`
4. `docker-compose up -d db redis log_aggregator`
5. Run backend locally with `uvicorn`

### Path C: Production (Cloud)
1. `cp backend/.env.web.example backend/.env`
2. Set all secrets (SECRET_KEY, API keys, etc.)
3. Use cloud database and Redis services
4. `docker-compose -f docker-compose.prod.yml up -d`
5. Configure SSL/TLS with Let's Encrypt

---

**Need Help?** Check the relevant guide or search logs:
```bash
docker-compose logs -f | grep -i "error\|warning"
```

