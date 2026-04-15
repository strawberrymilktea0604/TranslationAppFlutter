## 🚀 Refresh Token & Logout - Quick Start

**Status:** ✅ Production Ready  
**Implementation Date:** April 15, 2026

---

## 📦 What You Need to Know

Your backend now has a **secure token refresh and logout system** with:
- Single-use refresh tokens (prevents replay attacks)
- Hybrid Redis + Database storage (fast + persistent)
- Per-session logout (default) + multi-device logout (emergency)
- Graceful fallback if Redis is unavailable

---

## ⚡ 1-Minute Setup

### Step 1: Run the migration
```bash
cd backend
alembic upgrade head
```

### Step 2: Install dependencies
```bash
pip install -r requirements.txt
```

### Step 3: Start Redis (if using Docker)
```bash
docker-compose up -d redis
```

### Step 4: Restart backend
```bash
uvicorn app.main:app --reload
```

✅ Done! Test with:
```bash
curl http://localhost:8000/health
```

Response should show:
```json
{
  "status": "ok",
  "environment": "development",
  "project": "TranslationApp API",
  "redis": "ok"
}
```

---

## 🔗 API Endpoints Reference

| Endpoint | Method | Purpose | Body |
|----------|--------|---------|------|
| `/api/v1/auth/login` | POST | Login | `{"username": "email", "password": "pwd"}` |
| `/api/v1/auth/register` | POST | Register | `{"email": "user@example.com", "password": "Secret123"}` |
| **`/api/v1/auth/refresh`** | POST | Get new access token | `{"refresh_token": "eyJ..."}` |
| **`/api/v1/auth/logout`** | POST | Logout current session | `{"access_token": "...", "refresh_token": "..."}` |
| **`/api/v1/auth/logout-all`** | POST | Logout all devices | (requires Bearer auth) |

---

## 💻 Quick Test (Copy-Paste)

### 1. Login
```bash
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=test@example.com&password=SecurePass123"
```

Save the `access_token` and `refresh_token` from response.

### 2. Test Protected Endpoint (with access token)
```bash
curl -X GET "http://localhost:8000/api/v1/profile" \
  -H "Authorization: Bearer <YOUR_ACCESS_TOKEN_HERE>"
```

Should return 200 with profile data.

### 3. Refresh Access Token (before it expires)
```bash
curl -X POST "http://localhost:8000/api/v1/auth/refresh" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<YOUR_REFRESH_TOKEN_HERE>"}'
```

You get a **NEW** refresh token. Old one is now invalid (single-use).

### 4. Logout (revoke tokens)
```bash
curl -X POST "http://localhost:8000/api/v1/auth/logout" \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "<OLD_ACCESS_TOKEN>",
    "refresh_token": "<OLD_REFRESH_TOKEN>"
  }'
```

### 5. Try to use revoked token (should fail)
```bash
curl -X GET "http://localhost:8000/api/v1/profile" \
  -H "Authorization: Bearer <REVOKED_ACCESS_TOKEN>"
```

Returns 401 Unauthorized ✅

---

## 🎯 Key Features Explained

### Single-Use Refresh Tokens
**What it means:** Each time you refresh, you get a new refresh token. The old one becomes useless.

**Why it matters:** If someone steals a token, they can only use it once. After that, they're blocked.

**Example timeline:**
```
Time 0: User logs in → access_token_A + refresh_token_A
Time 1: Refresh with refresh_token_A → access_token_B + refresh_token_B
        (refresh_token_A is now REVOKED)
Time 2: Try to refresh with refresh_token_A → ERROR "already used"
Time 2b: Refresh with refresh_token_B → access_token_C + refresh_token_C
         (refresh_token_B is now REVOKED)
```

### Hybrid Redis + Database Storage
**Why both?**
- **Redis:** Instant lookup = faster API responses (O(1) check)
- **Database:** Persistent record = survives Redis restart + audit trail

**How it works:**
1. When token is revoked → immediately added to Redis (instant)
2. Also marked in database as `is_revoked = true` (permanent)
3. If Redis crashes → system instantly falls back to database checks
4. No data loss, just slightly slower response times

### Per-Session Logout (Default)
**What it means:** When you logout, only YOUR current session is logged out.

**Example:**
- Device A logs in → tokens_A issued
- Device B logs in → tokens_B issued
- Device A logs out → only tokens_A revoked, tokens_B still work
- Device B can keep using tokens_B normally

**Use case:** Multiple devices, logout one without affecting others.

### Logout All (Emergency)
**What it means:** Log out from all your devices at once.

**How to use:**
```bash
curl -X POST "http://localhost:8000/api/v1/auth/logout-all" \
  -H "Authorization: Bearer <CURRENT_ACCESS_TOKEN>"
```

**Use case:** Account compromised? Logout everywhere with one call.

---

## 🔐 Security Properties

| What | How It's Secure |
|------|---|
| Token Theft | Short expiry (15 min) + single-use refresh tokens |
| Replay Attacks | Each refresh invalidates old token |
| Unauthorized Access | Tokens revoked immediately (Redis) or from DB |
| Data Breach | Even if DB stolen, tokens still expire + can be revoked |
| Redis Down | System falls back to database checks |

---

## ⚙️ Configuration

All settings in `backend/app/core/config.py`:

```python
ACCESS_TOKEN_EXPIRE_MINUTES = 15      # Change to adjust access token lifetime
REFRESH_TOKEN_EXPIRE_DAYS = 7         # Change to adjust refresh token lifetime
REDIS_URL = "redis://redis:6379"      # Change for different Redis instance
```

For `.env` overrides:
```env
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=14
REDIS_URL=redis://your-redis-server:6379
```

---

## 🐛 Troubleshooting

### Q: I get "Token already used" on refresh
**A:** First time is normal! That means single-use is working. Use the NEW refresh token from the response.

### Q: Redis health check fails
**A:** Make sure Redis is running. If using Docker:
```bash
docker-compose ps redis      # Check status
docker-compose up -d redis   # Start it
redis-cli ping               # Test connection
```

### Q: Logout doesn't work
**A:** Make sure you're providing BOTH access_token and refresh_token in the logout request.

### Q: Get "Could not validate credentials"
**A:** Your token might be:
- Expired (try refreshing with refresh token)
- Revoked (logout earlier, need to login again)
- Invalid format (check you're using Bearer token correctly)

---

## 📊 Token Lifetime Example

```
Login at 10:00 AM:
├─ access_token expires: 10:15 AM (15 minutes)
└─ refresh_token expires: 10:00 AM next week (7 days)

At 10:10 AM:
├─ Use access_token → ✅ Works
├─ Use refresh_token → ✅ Works but refreshes tokens
└─ After refresh:
    ├─ NEW access_token expires: 10:25 AM
    ├─ NEW refresh_token expires: 10:10 AM next week
    └─ OLD refresh_token → ❌ Revoked (single-use)

At 10:16 AM (after access_token expires):
├─ access_token → ❌ Expired (use refresh instead)
└─ refresh_token → ✅ Use to get new access_token

At 10:10 AM next week (refresh_token expires):
├─ refresh_token → ❌ Expired (must login again)
└─ User must: POST /login → get new token pair
```

---

## 🔄 Complete User Flow

```
┌───────────────────────────────────────────────┐
│ 1. User Registers / Logs In                   │
│    POST /auth/register or /auth/login         │
│                                               │
│    Response:                                  │
│    {                                          │
│      "access_token": "eyJ...",               │
│      "refresh_token": "eyJ...",              │
│      "expires_in": 900                        │
│    }                                          │
└───────────────┬─────────────────────────────┘
                │
        ┌───────▼──────────┐
        │ 2. Use App       │
        │ GET /protected   │
        │ Header:          │
        │ Authorization:   │
        │ Bearer           │
        │ {access_token}   │
        └───────┬──────────┘
                │
          ┌─────┴─────┐
          │           │
    ┌─────▼──┐   ┌───▼──────┐
    │ ✅ OK  │   │ ❌ 401   │
    │ (works)│   │ (expired)│
    └────────┘   └───┬──────┘
                     │
                     │ Token expired?
                     ▼
            ┌─────────────────┐
            │ 3. Refresh      │
            │ POST /refresh   │
            │ {refresh_token} │
            └────────┬────────┘
                     │
            ┌────────▼─────────┐
            │ New tokens:      │
            │ access_token     │
            │ refresh_token    │
            │ (old refresh now │
            │  single-use)     │
            └────────┬─────────┘
                     │
            ┌────────▼──────────┐
            │ Continue using    │
            │ new access_token  │
            └───────────────────┘
                     │
                     │ Want to logout?
                     ▼
            ┌─────────────────────┐
            │ 4. Logout           │
            │ POST /logout        │
            │ {access_token,      │
            │  refresh_token}     │
            └────────┬────────────┘
                     │
            ┌────────▼─────────────┐
            │ Tokens revoked:      │
            │ ❌ access_token      │
            │ ❌ refresh_token     │
            │                      │
            │ Must login again     │
            └──────────────────────┘
                     │
                     │ Compromised account?
                     ▼
            ┌──────────────────────┐
            │ 5. Emergency Logout  │
            │ POST /logout-all     │
            │ (all devices logged  │
            │  out at once)        │
            └──────────────────────┘
```

---

## 📝 Implementation Files

**Core Files Modified:**
- `backend/app/core/security.py` — Token creation with JTI
- `backend/app/core/dependencies.py` — Revocation check
- `backend/app/core/config.py` — Redis configuration
- `backend/app/core/redis_client.py` — **NEW** Redis wrapper
- `backend/app/services/token_service.py` — **NEW** Token lifecycle
- `backend/app/models/user.py` — UserToken with JTI
- `backend/app/api/v1/endpoints/auth.py` — New endpoints
- `backend/app/main.py` — Redis startup/shutdown

**Database:**
- `alembic/versions/add_jti_to_user_tokens.py` — **NEW** Migration

---

## ✨ Next Steps (Optional)

1. **Add rate limiting** to refresh endpoint (prevent brute force)
2. **Add audit logging** (track all token operations)
3. **Setup background cleanup** (remove old expired tokens weekly)
4. **Add email notifications** (alert on suspicious activity)
5. **Integrate with 2FA** (for high-security accounts)

---

**Questions?** Check [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for detailed documentation.

**Status:** ✅ Ready for Production Use  
**Last Updated:** April 15, 2026
