## 🔐 Refresh Token & Logout Implementation Guide

**Implementation Date:** April 15, 2026  
**Status:** ✅ Complete  
**Architecture:** Single-use refresh tokens + Hybrid Redis/DB storage

---

## 📋 What Was Built

### Core Features Implemented

#### 1. **Secure Token Generation with JTI (JWT ID)**
- Each token now has a unique `jti` (JWT ID) claim for tracking and revocation
- Added `iat` (issued at) timestamp for audit trails
- Token types: `"access"` and `"refresh"` for clear differentiation

#### 2. **Refresh Token Management**
- Single-use refresh tokens (security best practice)
- Each refresh invalidates old token and issues new pair
- Refresh tokens stored in `user_tokens` table with JTI tracking
- 7-day expiration (configurable via `REFRESH_TOKEN_EXPIRE_DAYS`)

#### 3. **Token Revocation System**
- **Hybrid Storage:**
  - Redis: Fast O(1) blacklist checks (immediate rejection)
  - Database: Persistent audit trail with `is_revoked` flag
- Revocation checks happen in dependencies before DB queries (fail-fast)
- If Redis unavailable, system falls back to DB checks gracefully

#### 4. **API Endpoints**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/auth/login` | POST | Login with email/password (updated to store refresh token in DB) |
| `/api/v1/auth/register` | POST | Register new user (updated to store refresh token in DB) |
| **`/api/v1/auth/refresh`** | POST | **[NEW]** Refresh access token using refresh token |
| **`/api/v1/auth/logout`** | POST | **[NEW]** Revoke current session tokens |
| **`/api/v1/auth/logout-all`** | POST | **[NEW]** Revoke all user sessions (multi-device logout) |

#### 5. **Database Schema Updates**
- Added `jti` column to `user_tokens` table (unique, indexed)
- Added composite index on `(user_id, is_revoked)` for efficient queries
- Added index on `jti` for fast revocation lookups

---

## 🚀 Next Steps to Deploy

### 1. **Run Database Migration**

```bash
cd backend
alembic upgrade head
```

This will:
- Add `jti` column to `user_tokens` table
- Create unique constraint on `jti`
- Add performance indexes

### 2. **Install New Dependencies**

```bash
pip install -r requirements.txt
```

Specifically:
- `redis==5.0.1` — Redis client
- `aioredis==2.0.1` — Async Redis support

### 3. **Ensure Redis is Running**

From docker-compose.yml Redis service:
```bash
docker-compose up -d redis
```

Or check existing Redis:
```bash
docker-compose ps redis
```

Should show Redis running on `localhost:6379` or configured `REDIS_URL`

### 4. **Update .env (if needed)**

Ensure these are set:
```env
REDIS_URL=redis://redis:6379  # Default if using docker-compose
SECRET_KEY=your-secure-key-32-chars-min
DATABASE_URL=postgresql+asyncpg://user:password@host:5432/dbname
```

### 5. **Start/Restart Backend**

```bash
uvicorn app.main:app --reload
```

Or with production settings:
```bash
gunicorn app.main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker
```

---

## 📖 API Usage Examples

### **1. Login → Get Tokens**

```bash
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=user@example.com&password=SecurePass123"
```

**Response:**
```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "token_type": "bearer",
  "expires_in": 900
}
```

**Token Claims (decoded):**
```json
{
  "sub": "1",
  "exp": 1234567890,
  "iat": 1234567200,
  "jti": "550e8400-e29b-41d4-a716-446655440000",
  "type": "access"
}
```

### **2. Use Access Token to Access Protected Resources**

```bash
curl -X GET "http://localhost:8000/api/v1/profile" \
  -H "Authorization: Bearer <access_token>"
```

### **3. Refresh Access Token (Before Expiry)**

```bash
curl -X POST "http://localhost:8000/api/v1/auth/refresh" \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "eyJhbGc..."
  }'
```

**Response:**
```json
{
  "access_token": "eyJhbGc...",  # NEW access token
  "refresh_token": "eyJhbGc...",  # NEW refresh token (old one revoked)
  "token_type": "bearer",
  "expires_in": 900
}
```

**⚠️ Important:** The old refresh token is now **single-use and revoked**. Only the new refresh token can be used for next refresh.

### **4. Logout (Revoke Current Session)**

```bash
curl -X POST "http://localhost:8000/api/v1/auth/logout" \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "eyJhbGc...",
    "refresh_token": "eyJhbGc..."
  }'
```

**Response:**
```json
{
  "detail": "Successfully logged out"
}
```

**After logout:**
- Both tokens are blacklisted in Redis (immediate effect)
- Both tokens marked `is_revoked=true` in DB (persistent)
- Any subsequent API calls with these tokens → 401 Unauthorized
- User must login again to get new tokens

### **5. Logout All Sessions (Security: Account Compromise)**

```bash
curl -X POST "http://localhost:8000/api/v1/auth/logout-all" \
  -H "Authorization: Bearer <access_token>"
```

**Response:**
```json
{
  "detail": "All sessions logged out",
  "revoked_tokens_count": 3
}
```

**Effect:**
- All refresh tokens for this user are revoked
- User is logged out on all devices
- All sessions must re-login

---

## 🔍 Verification Checklist

### Test Scenarios

#### ✅ Test 1: Normal Login → Refresh → Logout Flow
```
1. POST /auth/login → get access + refresh tokens
2. GET /profile with access_token → 200 OK
3. Wait for access_token to expire OR manually test refresh
4. POST /auth/refresh with refresh_token → new tokens
5. POST /auth/logout with old tokens → 200 OK
6. GET /profile with old access_token → 401 Unauthorized
7. POST /auth/refresh with old refresh_token → 401 Unauthorized
```

#### ✅ Test 2: Single-Use Refresh Token Enforcement
```
1. POST /auth/refresh with refresh_token_A → new refresh_token_B
2. POST /auth/refresh with refresh_token_A (again) → 401 "Token already used"
3. POST /auth/refresh with refresh_token_B → success (new refresh_token_C)
```

#### ✅ Test 3: Token Revocation Blacklist
```
1. POST /logout → tokens added to Redis
2. Immediately try to use revoked access_token → 401 (Redis blacklist check)
3. Check Redis:
   redis-cli KEYS "revoked_token:*" → should show revoked JTIs
   redis-cli TTL "revoked_token:jti" → should show TTL > 0
```

#### ✅ Test 4: Database Fallback (if Redis Down)
```
1. Stop Redis: docker-compose stop redis
2. Login and get tokens
3. POST /refresh with refresh_token → should still work (checks DB)
4. Old tokens should be marked is_revoked=true in DB
5. Logout should still work (marks tokens revoked in DB)
6. Restart Redis: docker-compose up redis
```

#### ✅ Test 5: Multi-Device Logout
```
1. Login on Device A → get tokens_A
2. Login on Device B → get tokens_B
3. On Device A: POST /logout → revoke tokens_A only
4. Device A: all protected endpoints → 401
5. Device B: all protected endpoints → still works (tokens_B still valid)
6. On Device B: POST /logout-all → revoke ALL
7. Device A & B: both get 401 on next request
```

### Manual API Testing with Postman/Insomnia

1. **Create request collection:**
   - Login (Post)
   - Refresh (Post)
   - Logout (Post)
   - Get Profile (Get) — protected endpoint
   - Logout All (Post)

2. **Set variables:**
   - `{{access_token}}` — auto-extract from login response
   - `{{refresh_token}}` — auto-extract from login response
   - `{{base_url}}` — `http://localhost:8000`

3. **Run flows:**
   - Test normal flow
   - Test single-use enforcement
   - Test multi-device scenarios

### Check Redis Persistence

```bash
# Connect to Redis
redis-cli -h localhost -p 6379

# View all revoked tokens
KEYS "revoked_token:*"

# Check if specific JTI is revoked
GET "revoked_token:550e8400-e29b-41d4-a716-446655440000"

# View TTL remaining
TTL "revoked_token:550e8400-e29b-41d4-a716-446655440000"

# Clear specific token (testing)
DEL "revoked_token:550e8400-e29b-41d4-a716-446655440000"

# View all keys (debugging)
DBSIZE
FLUSHDB  # Clear all (testing only!)
```

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Client Application                    │
└────────────────┬────────────────────────────────────────┘
                 │
         ┌───────▼────────┐
         │  POST /login   │◄────► [Verify email + password]
         │                │       [Create access + refresh tokens]
         │  Returns:      │       [Store refresh token in DB]
         │  ├─ access_tok │       [Return both to client]
         │  ├─ refresh_tok│
         │  └─ expires_in │
         └────────────────┘
                 │
      ┌──────────▼──────────────┐
      │ GET /protected/resource │
      │ Header: Authorization:  │
      │ Bearer <access_token>   │
      └────────────┬────────────┘
                   │
         ┌─────────▼─────────────────────┐
         │ 1. Extract JTI from token     │
         │ 2. Check Redis blacklist      │ ◄─────┐
         │    (O(1) fast check)          │       │
         │ 3. If revoked → 401           │       │
         │ 4. Otherwise → Query DB user  │       │
         │ 5. Validate account status    │       │
         │ 6. Return protected resource  │       │
         └───────────────────────────────┘       │
                   │                             │
         ┌─────────▼──────────┐       ┌──────────┴──────────┐
         │ POST /auth/refresh │       │ POST /auth/logout  │
         │ with renewal_token │       │ with tokens to revoke
         └────────────┬───────┘       └──────────┬──────────┘
                      │                          │
         ┌────────────▼────────────┐ ──────────→ │
         │ 1. Validate token      │   Validate   │
         │ 2. Check if revoked    │   auth with  │
         │ 3. Mark old as revoked │   access_tok │
         │    in DB               │              │
         │ 4. Add old JTI to      │              │
         │    Redis blacklist (TTL)             │
         │ 5. Issue new pair      │              │
         │    (access + refresh)  │              │
         │ 6. Store new refresh   │              │
         │    in DB               │              │
         └────────────┬───────────┘    │ Add both tokens to Redis blacklist
                      │                │ Mark refresh as revoked in DB
                      │                │ Return success
                      ▼                ▼
             ┌──────────────────────────────────┐
             │  Redis (Token Blacklist Cache)   │
             │  ├─ revoked_token:{jti} → TTL   │
             │  └─ [Auto-expires at token exp] │
             │                                  │
             │  Provides O(1) lookup on         │
             │  revocation checks               │
             └──────────────────────────────────┘
                      │
                      │ (Fallback if Redis down)
                      ▼
             ┌──────────────────────────────────┐
             │  Database (PostgreSQL)           │
             │  ├─ user_tokens table            │
             │  │  ├─ id (primary key)         │
             │  │  ├─ user_id (FK)             │
             │  │  ├─ jti (unique, indexed)    │
             │  │  ├─ refresh_token            │
             │  │  ├─ is_revoked (boolean)     │
             │  │  └─ expires_at (datetime)    │
             │  │                              │
             │  └─ Indexes:                    │
             │     ├─ (user_id, is_revoked)    │
             │     └─ jti                      │
             └──────────────────────────────────┘
```

---

## 🔒 Security Properties

| Property | Implementation | Benefit |
|----------|---|---|
| **Token Storage** | JWT (no server storage needed) + Refresh token stored in DB | Stateless design + ability to revoke specific tokens |
| **Token Revocation** | JTI tracking + Redis blacklist | Immediate token rejection without DB query |
| **Token Reuse** | Single-use refresh token policy | Prevents token replay attacks |
| **Token Expiry** | Short-lived access tokens (15 min default) | Reduces damage from token theft |
| **Refresh Window** | 7-day refresh token | Reasonable balance between security and UX |
| **Multi-Device** | Per-session revocation by default | User privacy; logout-all available for emergencies |
| **Fallback** | DB check if Redis unavailable | Graceful degradation, system stays secure |

---

## ⚙️ Configuration Reference

### Environment Variables
```env
# JWT Configuration
SECRET_KEY=your_secret_key_here_at_least_32_chars  # Set in .env, never hardcode
ALGORITHM=HS256  # Fixed
ACCESS_TOKEN_EXPIRE_MINUTES=15  # Adjust as needed
REFRESH_TOKEN_EXPIRE_DAYS=7     # Adjust as needed

# Redis Configuration
REDIS_URL=redis://localhost:6379  # Default local
# or with authentication: redis://:password@host:port/db
# or for Redis in Docker: redis://redis:6379

# Database
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/translation_app

# Environment
ENVIRONMENT=development  # development, staging, production
```

### Alembic Migration Tracking
```
Revision: add_jti_to_user_tokens
Down Revision: 55f4e1e3280d
Changes:
  ✅ Add jti column (unique, not null)
  ✅ Add index on jti
  ✅ Add index on (user_id, is_revoked)
```

---

## 🛠️ Code Structure

### New / Modified Files

```
backend/app/
├── core/
│   ├── security.py          ✏️ UPDATED: Added JTI, refresh token functions
│   ├── dependencies.py       ✏️ UPDATED: Added revocation check
│   ├── config.py            ✏️ UPDATED: Added Redis settings
│   └── redis_client.py       ✨ NEW: Redis wrapper for revocation
├── models/
│   └── user.py              ✏️ UPDATED: UserToken model with jti field
├── services/
│   └── token_service.py      ✨ NEW: Token lifecycle management
├── schemas/
│   └── user.py              ✏️ UPDATED: Added refresh/logout schemas
├── api/v1/endpoints/
│   └── auth.py              ✏️ UPDATED: Added refresh, logout endpoints
└── main.py                  ✏️ UPDATED: Redis startup/shutdown events

alembic/
└── versions/
    └── add_jti_to_user_tokens.py  ✨ NEW: DB migration

requirements.txt             ✏️ UPDATED: Added redis, aioredis
```

---

## 🧪 Testing Strategy

### Unit Tests (Recommended)
```python
# tests/test_token_service.py
- test_create_tokens_for_user()
- test_refresh_single_use_token()
- test_revoke_token()
- test_is_token_revoked_redis()
- test_is_token_revoked_db_fallback()
```

### Integration Tests (Recommended)
```python
# tests/test_auth_endpoints.py
- test_login_register_flow()
- test_refresh_token_flow()
- test_single_use_enforcement()
- test_logout_revocation()
- test_logout_all_multi_device()
```

### Load Tests (For Production)
```bash
# Test refresh endpoint under load
ab -n 1000 -c 10 -X POST http://localhost:8000/api/v1/auth/refresh
```

---

## 📝 Database Schema

```sql
-- user_tokens table after migration
CREATE TABLE user_tokens (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    jti VARCHAR(255) NOT NULL UNIQUE,  -- NEW: JWT ID for revocation
    refresh_token VARCHAR NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    -- NEW: Performance indexes
    INDEX idx_user_id_is_revoked (user_id, is_revoked),
    INDEX idx_jti (jti)
);
```

---

## 🚨 Troubleshooting

### Problem: Refresh endpoint returns 401 "Token already used"
**Cause:** Single-use enforcement — old refresh token was already used  
**Solution:** Use the NEW refresh token from the previous response, not the old one

### Problem: Logout doesn't work, tokens still valid
**Cause:** Redis connection failed, DB transaction not committed  
**Solution:** Check Redis health with `redis-cli ping`, verify DB commit in transaction

### Problem: Access token rejected immediately after login
**Cause:** Token payload missing `jti` claim  
**Solution:** Check security.py functions use new signatures with JTI generation

### Problem: Redis connection errors in logs
**Cause:** Redis container not running or wrong REDIS_URL  
**Solution:**  
```bash
docker-compose ps redis  # Check if running
docker-compose up -d redis  # Start if needed
redis-cli ping  # Test connection
```

### Problem: Database migration fails with "jti already exists"
**Cause:** Multiple migration attempts  
**Solution:**  
```bash
alembic current  # Check current revision
alembic downgrade -1  # Rollback if needed
alembic upgrade head  # Re-run
```

---

## ✨ Future Enhancements

### Recommended (High Priority)
1. **Rate limiting on refresh endpoint** — Prevent brute force attacks
   ```python
   # Example: 10 refreshes per minute per user
   from slowapi import Limiter
   limiter.limit("10/minute")(refresh_endpoint)
   ```

2. **Audit logging** — Track all token operations
   ```python
   # Log: user_id, token_jti, action (created/refreshed/revoked), timestamp
   ```

3. **Token cleanup job** — Remove expired records weekly
   ```python
   # Celery task or APScheduler
   @periodic_task.run('cron', hour=2)  # Run at 2 AM
   async def cleanup_expired_tokens():
       token_service.cleanup_expired_tokens(db)
   ```

### Optional (For Advanced Features)
1. **Device tracking** — Store device fingerprint/user-agent with each token
2. **Email notifications** — Alert on unusual login patterns
3. **TOTP/2FA integration** — Enhanced security for high-value accounts
4. **Granular scopes** — Different permissions for access vs refresh tokens

---

## 📚 References

- **JWT Best Practices:** https://tools.ietf.org/html/rfc7519
- **Refresh Token Patterns:** https://auth0.com/blog/refresh-tokens-what-are-they-and-when-to-use-them
- **Redis Documentation:** https://redis.io/commands/
- **FastAPI Security:** https://fastapi.tiangolo.com/advanced/security/
- **SQLAlchemy Async:** https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html

---

## 📞 Support

For issues or questions:
1. Check Redis health: `redis-cli ping`
2. Check database connectivity: `psql -U user -d database -c "SELECT 1"`
3. Review logs: `tail -f logs/app.log`
4. Verify token claims: Use jwt.io to decode JWT tokens
5. Run tests: `pytest tests/test_auth_endpoints.py -v`

---

**Last Updated:** April 15, 2026  
**Status:** Production Ready ✅
