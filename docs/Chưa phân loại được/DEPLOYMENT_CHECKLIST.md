# Image Translation Pipeline - Deployment Checklist

## Pre-Deployment

### System Requirements
- [ ] Python 3.12+
- [ ] PostgreSQL 15+ (or use Docker)
- [ ] Redis 7+ (or use Docker)
- [ ] 2GB RAM minimum (4GB recommended)
- [ ] 10GB disk space

### Development Environment
- [ ] Python virtual environment created
- [ ] All dependencies installed: `pip install -r requirements.txt`
- [ ] .env file configured with:
  - [ ] DATABASE_URL
  - [ ] REDIS_URL
  - [ ] SECRET_KEY
  - [ ] JWT settings

### System Dependencies
- [ ] Tesseract OCR installed
  ```bash
  # Ubuntu/Debian
  sudo apt-get install -y \
    tesseract-ocr \
    libtesseract-dev \
    libleptonica-dev \
    libsm6 libxext6 libxrender-dev \
    libgl1-mesa-glx
  ```
- [ ] Python development headers installed

---

## Local Testing

### Backend Tests
- [ ] Unit tests pass: `pytest backend/tests/test_image_translation.py -v`
- [ ] Fast tests pass: `pytest backend/tests/ -m "not slow"`
- [ ] No lint errors: `pylint backend/app/`
- [ ] Code formatting: `black backend/`

### API Testing
- [ ] Health endpoint works: `curl http://localhost:8000/health`
- [ ] Single image translation tested manually
- [ ] Batch image translation tested
- [ ] Error handling verified (invalid files, etc.)
- [ ] Rate limiting verified

### Performance Testing
- [ ] Response time < 2 seconds with cache
- [ ] Response time < 7 seconds for new translation
- [ ] Memory usage monitored (should be < 200MB)
- [ ] Concurrent requests tested (10+ simultaneous)

### Memory Safety Testing
- [ ] No temporary files created in /tmp: `ls -la /tmp/ | wc -l`
- [ ] Memory is properly cleaned up
- [ ] Garbage collection working: `import gc; gc.collect()`

---

## Docker Deployment

### Docker Build
- [ ] Dockerfile has no errors
- [ ] System dependencies installed in Docker
- [ ] Requirements.txt updated with all packages
- [ ] Docker image builds: `docker build -t translation-backend backend/`
- [ ] Image size reasonable (< 1GB)

### Docker Compose
- [ ] docker-compose.yml is valid YAML
- [ ] Services defined: backend, db, redis
- [ ] Ports mapped correctly
- [ ] Volumes configured for persistence
- [ ] Health checks configured
- [ ] Environment variables configured

### Container Testing
- [ ] Containers start: `docker-compose up`
- [ ] No startup errors in logs
- [ ] Health check passes: `docker-compose ps`
- [ ] Services accessible:
  - [ ] Backend: http://localhost:8000
  - [ ] Database: localhost:5433
  - [ ] Redis: localhost:6379

---

## Database

### Migrations
- [ ] Alembic migrations up to date
- [ ] Database schema matches models
- [ ] Indexes created for performance
- [ ] Test data inserted (optional)

### Backup
- [ ] Database backup strategy defined
- [ ] Backup tested and verified
- [ ] Restore procedure documented

---

## API Gateway / Reverse Proxy

### Nginx (if used)
- [ ] nginx.conf configured for FastAPI
- [ ] SSL/TLS certificates installed
- [ ] Gzip compression enabled
- [ ] Rate limiting rules set
- [ ] nginx tests pass: `nginx -t`

### Load Balancing (if multiple backends)
- [ ] Load balancer health checks configured
- [ ] Session affinity not required (stateless)
- [ ] Timeout settings appropriate

---

## Security

### Authentication
- [ ] JWT tokens configured
- [ ] Refresh token mechanism working
- [ ] Token expiration reasonable (e.g., 24 hours)
- [ ] Secret key is strong and secure

### Authorization
- [ ] Rate limiting working per-user
- [ ] Rate limiting working per-IP for guests
- [ ] Admin endpoints require authentication

### Input Validation
- [ ] Image file size limits enforced (10MB)
- [ ] File type validation working
- [ ] Malicious input handling tested
- [ ] SQL injection prevention (SQLAlchemy ORM)
- [ ] XSS prevention (no user input in HTML)

### CORS
- [ ] CORS settings configured
- [ ] Allowed origins defined
- [ ] Credentials settings correct
- [ ] Preflight requests handled

### Data Privacy
- [ ] HTTPS enforced (not HTTP)
- [ ] No sensitive data in logs
- [ ] No image data stored permanently
- [ ] Cleanup after use confirmed
- [ ] GDPR compliance if EU users

---

## Monitoring & Logging

### Logging
- [ ] Log level set appropriately (DEBUG for dev, INFO for prod)
- [ ] Log rotation configured (if file-based)
- [ ] Sensitive data not logged (no passwords, tokens)
- [ ] Logs parseable (JSON format recommended)

### Monitoring
- [ ] CPU usage monitored
- [ ] Memory usage monitored
- [ ] Disk space monitored
- [ ] Database connections monitored
- [ ] Redis connections monitored
- [ ] API response times monitored

### Alerting
- [ ] High memory usage alert
- [ ] API error rate alert
- [ ] Database connection pool exhaustion alert
- [ ] Redis connection issues alert
- [ ] Disk space low alert

### Metrics
- [ ] Prometheus metrics enabled (if used)
- [ ] Grafana dashboards created (if used)
- [ ] Custom metrics added:
  - [ ] OCR extraction time
  - [ ] Translation cache hit rate
  - [ ] API response times

---

## Scaling

### Horizontal Scaling
- [ ] Backend is stateless (can run multiple instances)
- [ ] Redis is shared (no instance-specific state)
- [ ] Database is shared (no instance-specific data)
- [ ] Load balancer distributes traffic

### Vertical Scaling
- [ ] Can increase memory (max memory limited only by hardware)
- [ ] Can use GPU if needed (for future acceleration)

### Caching Strategy
- [ ] Redis cache hit rate > 70% (for typical usage)
- [ ] Cache TTL appropriate (1 hour default)
- [ ] Cache invalidation strategy clear

---

## Post-Deployment

### Smoke Tests
- [ ] Health endpoint responds: `/health`
- [ ] Simple image translation works
- [ ] Cache is working (second request faster)
- [ ] Error handling works (try with invalid image)

### Production Validation
- [ ] All endpoints accessible from production URL
- [ ] HTTPS working (if applicable)
- [ ] CORS headers correct
- [ ] Rate limiting working
- [ ] Logging to correct location
- [ ] Monitoring receiving metrics

### Rollback Plan
- [ ] Previous version backed up
- [ ] Database can be restored to previous state
- [ ] Quick rollback procedure documented
- [ ] Team knows how to execute rollback

---

## Documentation

### User Documentation
- [ ] API endpoints documented
- [ ] Request/response examples provided
- [ ] Error codes explained
- [ ] Rate limits documented
- [ ] Supported languages listed

### Developer Documentation
- [ ] Architecture documented
- [ ] API integration examples provided
- [ ] Setup instructions clear
- [ ] Troubleshooting guide created
- [ ] Contributing guidelines defined

### Operations Documentation
- [ ] Deployment procedure documented
- [ ] Monitoring procedure documented
- [ ] Incident response procedure documented
- [ ] Backup/restore procedure documented
- [ ] Scaling procedure documented

---

## Runbooks

### Common Issues

#### High Memory Usage
- [ ] Check OCR processing (normal ~100MB per request)
- [ ] Monitor concurrent requests
- [ ] Check for memory leaks (use memory profiler)
- [ ] Increase Docker memory limit if needed

#### OCR Slow
- [ ] Check CPU usage (OCR is CPU-bound)
- [ ] Consider reducing image size before OCR
- [ ] Check for OCR preprocessing overhead
- [ ] Profile OCR service

#### Cache Miss High
- [ ] Check if cache is working (Redis connectivity)
- [ ] Check cache TTL setting
- [ ] Monitor cache hit rate in metrics

#### Rate Limit Issues
- [ ] Check rate limit configuration
- [ ] Verify user authentication working
- [ ] Check IP tracking for guest users

---

## Sign-Off

### Deployment Manager
- [ ] Name: _______________
- [ ] Date: _______________
- [ ] Approved: [ ]

### QA
- [ ] All tests passed: [ ]
- [ ] No critical issues: [ ]
- [ ] Name: _______________
- [ ] Date: _______________

### DevOps
- [ ] Infrastructure ready: [ ]
- [ ] Monitoring configured: [ ]
- [ ] Alerts active: [ ]
- [ ] Name: _______________
- [ ] Date: _______________

---

## Quick Commands

```bash
# Build Docker image
docker build -t translation-backend backend/

# Start all services
docker-compose up --build

# Run tests
pytest backend/tests/test_image_translation.py -v

# Check health
curl http://localhost:8000/health

# View logs
docker-compose logs -f backend

# Stop containers
docker-compose down

# Database backup
docker exec translation_db pg_dump -U postgres > backup.sql

# Database restore
cat backup.sql | docker exec -i translation_db psql -U postgres
```

---

**Deployment Date**: ________________
**Deployed By**: ________________
**Status**: [ ] Ready [ ] In Progress [ ] Issues Found

---

*For support, contact DevOps team or check the documentation*
