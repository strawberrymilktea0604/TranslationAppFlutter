# AI API Rate Limiting Configuration Guide

**Status:** ✅ Production Ready  
**Last Updated:** May 24, 2026  
**Service:** AI Translation API Rate Limiter

---

## 📋 Overview

The AI API Rate Limiting system provides comprehensive protection against abuse and ensures fair resource allocation across different user types (guests, users, admins, premium).

**Key Features:**
- ✅ Redis-based distributed rate limiting
- ✅ Per-endpoint configuration (text, audio, image, conversation, vocabulary)
- ✅ Per-user-type limits (guest, user, admin, premium)
- ✅ Real-time status tracking and monitoring
- ✅ Graceful fallback if Redis unavailable (fail-open)
- ✅ Detailed audit logging

---

## 🎯 Default Rate Limits

### Request Types & Limits

| Request Type | Guest | User | Admin | Premium |
|---|---|---|---|---|
| **Text Translation** | 10/hr | 100/hr | 1000/hr | 500/hr |
| **Audio Translation** | 5/hr | 33/hr | 1000/hr | 500/hr |
| **Image Translation** | 3/hr | 25/hr | 1000/hr | 500/hr |
| **Conversation** | ❌ | 100/hr | 1000/hr | 500/hr |
| **Vocabulary** | 5/hr | 100/hr | 1000/hr | 500/hr |

**Formula:**
- Audio = Guest / 2, User / 3 of default
- Image = Guest / 3, User / 4 of default (most expensive)
- Conversation = User-only feature
- Vocabulary = Same as text

---

## ⚙️ Environment Configuration

### Add to `.env` file

```bash
# Rate Limiting - Base Limits (requests per hour)
GUEST_MAX_REQUESTS_PER_HOUR=10
USER_MAX_REQUESTS_PER_HOUR=100
ADMIN_MAX_REQUESTS_PER_HOUR=1000
PREMIUM_MAX_REQUESTS_PER_HOUR=500

# Rate Limit Window (seconds)
RATE_LIMIT_WINDOW_SECONDS=3600  # 1 hour

# Per-Request Character Limits
GUEST_MAX_CHAR_LENGTH=500
USER_MAX_CHAR_LENGTH=5000
ADMIN_MAX_CHAR_LENGTH=50000

# Fallback Provider (Google Translate API) Rate Limiting
FALLBACK_MAX_REQUESTS_PER_MINUTE=20  # Prevent IP ban
```

### Environment-Specific Examples

#### Development

```bash
# Development - Loose limits for testing
GUEST_MAX_REQUESTS_PER_HOUR=100
USER_MAX_REQUESTS_PER_HOUR=1000
ADMIN_MAX_REQUESTS_PER_HOUR=10000
RATE_LIMIT_WINDOW_SECONDS=3600
```

#### Staging

```bash
# Staging - Production-like limits
GUEST_MAX_REQUESTS_PER_HOUR=20
USER_MAX_REQUESTS_PER_HOUR=200
ADMIN_MAX_REQUESTS_PER_HOUR=2000
PREMIUM_MAX_REQUESTS_PER_HOUR=750
RATE_LIMIT_WINDOW_SECONDS=3600
```

#### Production

```bash
# Production - Strict limits
GUEST_MAX_REQUESTS_PER_HOUR=10
USER_MAX_REQUESTS_PER_HOUR=100
ADMIN_MAX_REQUESTS_PER_HOUR=1000
PREMIUM_MAX_REQUESTS_PER_HOUR=500
RATE_LIMIT_WINDOW_SECONDS=3600
FALLBACK_MAX_REQUESTS_PER_MINUTE=10
```

---

## 🔧 Implementation in Endpoints

### Basic Usage

```python
from app.services.rate_limiter import AIRateLimiter, RequestType, UserType
from fastapi import Request, Depends, HTTPException, status

limiter = AIRateLimiter()

@router.post("/translate/text")
async def translate_text(
    request: Request,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
):
    # Determine identifier and user type
    if current_user:
        identifier = f"user:{current_user.id}"
        user_type = UserType.USER if current_user.role == "user" else UserType.ADMIN
    else:
        identifier = f"guest:{request.client.host}"
        user_type = UserType.GUEST
    
    # Check rate limit
    limit_status = await limiter.check_limit(
        identifier=identifier,
        request_type=RequestType.TEXT_TRANSLATION,
        user_type=user_type,
        cost=1  # Cost of this request
    )
    
    if not limit_status["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "error": limit_status["error"],
                "reset_in_seconds": limit_status["reset_in_seconds"],
                "requests_limit": limit_status["requests_limit"],
            }
        )
    
    # Add rate limit info to response headers
    response_headers = {
        "X-RateLimit-Limit": str(limit_status["requests_limit"]),
        "X-RateLimit-Remaining": str(limit_status["requests_remaining"]),
        "X-RateLimit-Reset": str(int(limit_status["reset_in_seconds"])),
    }
    
    # ... process request ...
    
    return {
        "result": "...",
        "rate_limit": limit_status
    }, response_headers
```

### Advanced: Custom Costs

Some requests cost more quota. For example, translating 5000 characters might cost 5 requests:

```python
# Calculate cost based on request size
text_length = len(text)
cost = max(1, text_length // 1000)  # 1 request per 1000 chars

limit_status = await limiter.check_limit(
    identifier=identifier,
    request_type=RequestType.TEXT_TRANSLATION,
    user_type=user_type,
    cost=cost
)

if not limit_status["allowed"]:
    # User has insufficient quota for this request
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail=f"Request costs {cost} quota, but only {limit_status['requests_remaining']} remaining"
    )
```

---

## 📊 Monitoring & Admin Endpoints

### Get Rate Limit Status

```bash
# Check current rate limit status for a user
curl -X GET "http://localhost:8000/api/v1/admin/rate-limits/user:123" \
  -H "Authorization: Bearer ADMIN_TOKEN"

# Response:
{
  "identifier": "user:123",
  "user_type": "user",
  "status_by_type": {
    "text": {
      "allowed": true,
      "requests_used": 15,
      "requests_remaining": 85,
      "requests_limit": 100,
      "reset_in_seconds": 1800,
      "reset_at": "2026-05-24T12:30:00Z"
    },
    "audio": {
      "allowed": true,
      "requests_used": 5,
      "requests_remaining": 28,
      "requests_limit": 33,
      "reset_in_seconds": 1800
    },
    ...
  }
}
```

### Reset Rate Limit (Admin Only)

```bash
# Reset all limits for a user
curl -X POST "http://localhost:8000/api/v1/admin/rate-limits/user:123/reset" \
  -H "Authorization: Bearer ADMIN_TOKEN"

# Reset specific request type
curl -X POST "http://localhost:8000/api/v1/admin/rate-limits/user:123/reset?type=audio" \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

---

## 🚨 Rate Limit Response Examples

### Success Response (429 - Too Many Requests)

```json
{
  "detail": {
    "error": "Rate limit exceeded. Retry in 1234s",
    "reset_in_seconds": 1234,
    "requests_limit": 10,
    "requests_used": 10,
    "reset_at": "2026-05-24T12:30:00Z"
  }
}
HTTP Status: 429 Too Many Requests

Headers:
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1234
```

### Success Response (200 - OK)

```json
{
  "result": "translated text",
  "rate_limit": {
    "allowed": true,
    "requests_used": 5,
    "requests_remaining": 95,
    "requests_limit": 100,
    "reset_in_seconds": 3600,
    "reset_at": "2026-05-24T13:00:00Z"
  }
}
HTTP Status: 200 OK

Headers:
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 3600
```

---

## 🔒 Security Considerations

### IP-based vs User-based Limiting

- **Guests:** Limited by IP address (`guest:{IP}`)
  - Prevents DDoS from single IP
  - Shared limit across multiple users on same network
  
- **Authenticated Users:** Limited by user ID (`user:{ID}`)
  - Fair allocation per user
  - Not affected by shared network
  
- **Admins:** High limits for management tasks (`admin:{ID}`)
  - Used for batch operations, admin dashboards
  - Monitored separately

### Cost-Based Quota

Requests have associated costs to prevent abuse of expensive operations:

```
Text Translation:    cost = 1
Audio Translation:   cost = 2-5 (depends on duration)
Image Translation:   cost = 2-3 (depends on image size)
Conversation Stream: cost = variable (per utterance)
```

Example:
```python
# Translating 5000 characters costs 5 quota
cost = max(1, len(text) // 1000)
```

---

## 🛡️ Fallback Translation Rate Limiting

The Google Translate API (fallback provider) has its own rate limiting to prevent IP bans:

```bash
# Configure in .env
FALLBACK_MAX_REQUESTS_PER_MINUTE=20

# This creates a separate rate limit:
# rate_limit:fallback:google_translate:{identifier}
```

When fallback limit is exceeded:
- User can still try Google Cloud Translation API (if key configured)
- Cached results are used if available
- User gets HTTP 503 Service Unavailable with retry-after header

---

## 📈 Monitoring & Metrics

### Log Monitoring

Rate limit events are logged as:

```json
{
  "timestamp": "2026-05-24T12:00:00Z",
  "level": "INFO",
  "logger": "app.services.rate_limiter",
  "message": "Rate limit: user:123 (text) - Used: 5/100, Remaining: 95",
  "service": "TranslationApp API",
  "environment": "production"
}

{
  "timestamp": "2026-05-24T12:00:01Z",
  "level": "WARNING",
  "logger": "app.services.rate_limiter",
  "message": "Rate limit exceeded: guest:192.168.1.1 (text) - Used: 10, Limit: 10, Cost: 1",
  "service": "TranslationApp API"
}
```

### Prometheus Metrics (Future)

Once Prometheus integration is enabled:

```
rate_limit_requests_total{user_type="user",request_type="text",identifier="user:123"} 5
rate_limit_exceeded_total{user_type="guest",request_type="audio",identifier="guest:192.168.1.1"} 2
rate_limit_reset_seconds{identifier="user:123",request_type="text"} 3600
```

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| **Redis unavailable** | System fails gracefully - allows requests, logs warning |
| **Rate limit stuck** | Manually reset: `POST /api/v1/admin/rate-limits/{id}/reset` |
| **Wrong user type** | Check identifier format: `guest:IP`, `user:ID`, `admin:ID`, `premium:ID` |
| **Limits too strict** | Update `.env` and restart backend |
| **Character limit exceeded** | Split large texts; implement client-side chunking |

---

## 🚀 Future Enhancements

- [ ] Tiered pricing with credit/token system
- [ ] Time-based rate limiting (burst protection)
- [ ] Per-endpoint custom limits in admin dashboard
- [ ] Rate limit API for clients (check remaining quota before request)
- [ ] Prometheus/Grafana monitoring dashboard
- [ ] Rate limit warnings (notify user at 80% usage)
- [ ] Dynamic rate limiting based on system load
- [ ] Geo-based rate limiting (different limits by region)

---

## 📞 Support

- Check logs: `docker-compose logs -f backend | grep "rate_limit"`
- Admin panel: `http://localhost:8080/admin/rate-limits`
- API docs: `http://localhost:8080/docs`
