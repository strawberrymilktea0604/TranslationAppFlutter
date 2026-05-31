# Real-time Session Logging Guide

**Status:** ✅ Production Ready  
**Last Updated:** May 24, 2026  
**Service:** Real-time Session Event Logging with FluentD Integration

---

## 📋 Overview

Comprehensive structured logging system for real-time WebSocket sessions (conversation, STT, translation) with centralized aggregation via FluentD.

**Key Components:**
- ✅ Event-based session logging (start, end, error, etc.)
- ✅ Performance metrics (latency, throughput, success rates)
- ✅ JSON structured logging for easy parsing
- ✅ FluentD integration for log forwarding
- ✅ Multi-speaker conversation tracking
- ✅ Real-time error alerting capability

---

## 🎯 Log Event Types

### Session Lifecycle

```
SESSION_START        → Session created
    ↓
AUDIO_CHUNK_RECEIVED → Audio received from client
    ↓
UTTERANCE_STARTED    → User started speaking
    ↓
UTTERANCE_ENDED      → User stopped speaking
    ↓
STT_PROCESSING       → Converting speech to text
    ↓
STT_COMPLETED        → Speech recognized
    ↓
TRANSLATION_PROCESSING → Translating text
    ↓
TRANSLATION_COMPLETED  → Translation complete
    ↓
SPEAKER_CHANGED      → Different speaker detected
    ↓
SESSION_END          → Session closed
```

### Error Events

```
SESSION_ERROR        → Critical session failure
STT_ERROR            → Speech-to-text failed
TRANSLATION_ERROR    → Translation service failed
RATE_LIMIT_EXCEEDED  → User quota exceeded
CONNECTION_CLOSED    → Unexpected disconnect
```

---

## ⚙️ Environment Configuration

### Add to `.env`

```bash
# ==========================================
# LOGGING CONFIGURATION
# ==========================================

# Log Level
LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR, CRITICAL

# Log Format
LOG_FORMAT=json  # json or standard

# FluentD Configuration
FLUENTD_ENABLED=true
FLUENTD_HOST=log_aggregator  # Docker service name
FLUENTD_PORT=24224
FLUENTD_BUFFER_LIMIT=256m
FLUENTD_FLUSH_INTERVAL=10s

# Real-time Session Logging
REALTIME_SESSION_LOGGING_ENABLED=true
REALTIME_SESSION_VERBOSE=false  # Log every audio chunk (verbose) or summary only

# Session Event Retention
SESSION_LOG_RETENTION_DAYS=30
SESSION_LOG_COMPRESSION=true

# Performance Monitoring
PERFORMANCE_METRICS_ENABLED=true
METRICS_FLUSH_INTERVAL=60  # seconds

# Audit Logging
AUDIT_LOGGING_ENABLED=true
AUDIT_LOG_ADMIN_ACTIONS=true
AUDIT_LOG_USER_LOGIN=true

# Alert Thresholds
ERROR_RATE_ALERT_THRESHOLD=0.1  # Alert if error rate > 10%
LATENCY_ALERT_THRESHOLD_MS=5000  # Alert if latency > 5 seconds
```

### Environment-Specific Configurations

#### Development

```bash
LOG_LEVEL=DEBUG
REALTIME_SESSION_VERBOSE=true
FLUENTD_ENABLED=false  # Optional for dev
SESSION_LOG_RETENTION_DAYS=7
PERFORMANCE_METRICS_ENABLED=true
```

#### Staging

```bash
LOG_LEVEL=INFO
REALTIME_SESSION_VERBOSE=false
FLUENTD_ENABLED=true
SESSION_LOG_RETENTION_DAYS=14
PERFORMANCE_METRICS_ENABLED=true
```

#### Production

```bash
LOG_LEVEL=WARNING
REALTIME_SESSION_VERBOSE=false
FLUENTD_ENABLED=true
FLUENTD_BUFFER_LIMIT=512m
SESSION_LOG_RETENTION_DAYS=90
PERFORMANCE_METRICS_ENABLED=true
AUDIT_LOGGING_ENABLED=true
ERROR_RATE_ALERT_THRESHOLD=0.05
```

---

## 📊 Log Event Examples

### Session Start

```json
{
  "timestamp": "2026-05-24T12:00:00Z",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "session_start",
  "user_id": 123,
  "event_count": 1,
  "elapsed_seconds": 0,
  "details": {
    "source_language": "vi",
    "target_language": "en",
    "speaker": "SPEAKER_A"
  },
  "level": "INFO"
}
```

### Audio Chunk Received

```json
{
  "timestamp": "2026-05-24T12:00:01Z",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "audio_chunk_received",
  "user_id": 123,
  "event_count": 5,
  "elapsed_seconds": 1.2,
  "details": {
    "chunk_size_bytes": 4096,
    "total_bytes_received": 20480,
    "sample_rate": 16000,
    "channels": 1
  },
  "level": "DEBUG"
}
```

### STT Completed

```json
{
  "timestamp": "2026-05-24T12:00:05Z",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "stt_completed",
  "user_id": 123,
  "event_count": 15,
  "elapsed_seconds": 5.0,
  "latency_ms": 2500,
  "details": {
    "text": "Xin chào, bạn tên gì",
    "text_length": 20,
    "language": "vi",
    "confidence": 0.95,
    "speaker": "SPEAKER_A"
  },
  "level": "INFO"
}
```

### Translation Completed

```json
{
  "timestamp": "2026-05-24T12:00:06Z",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "translation_completed",
  "user_id": 123,
  "event_count": 16,
  "elapsed_seconds": 6.0,
  "latency_ms": 1200,
  "details": {
    "source_text": "Xin chào, bạn tên gì",
    "translated_text": "Hello, what is your name",
    "source_language": "vi",
    "target_language": "en",
    "provider": "google"
  },
  "level": "INFO"
}
```

### Error Event

```json
{
  "timestamp": "2026-05-24T12:00:10Z",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "stt_error",
  "user_id": 123,
  "event_count": 20,
  "elapsed_seconds": 10.0,
  "latency_ms": 5000,
  "error": "Audio quality too poor for recognition",
  "level": "ERROR"
}
```

### Session End Summary

```json
{
  "timestamp": "2026-05-24T12:05:00Z",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "session_end",
  "user_id": 123,
  "event_count": 150,
  "elapsed_seconds": 300.0,
  "details": {
    "status": "completed",
    "total_duration_seconds": 300.0,
    "total_events": 150,
    "bytes_received": 1024000,
    "bytes_transmitted": 256000,
    "avg_event_latency_ms": 2000.0
  },
  "level": "INFO"
}
```

---

## 🔧 FluentD Configuration

### Update `backend/fluentd/fluent.conf`

```xml
<!-- Input from backend (from docker logging driver) -->
<source>
  @type tcp
  port 24224
  bind 0.0.0.0
  <parse>
    @type json
    time_format %iso8601
  </parse>
  tag realtime_session.*
</source>

<!-- Input from Docker container logs -->
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<!-- Filter to enrich logs -->
<filter realtime_session.**>
  @type record_modifier
  <replace>
    key hostname
    expression ${Socket.gethostname}
  </replace>
</filter>

<!-- Output to file (for development) -->
<match realtime_session.**>
  @type file
  path /fluentd/log/session.%Y-%m-%d.log
  <buffer time>
    timekey 86400
    timekey_wait 10m
  </buffer>
  <format>
    @type json
  </format>
</match>

<!-- Output to Elasticsearch (for production) -->
<!--
<match realtime_session.**>
  @type elasticsearch
  host elasticsearch
  port 9200
  index_name realtime_session-%Y.%m.%d
  type_name _doc
  <buffer tag,time>
    timekey 3600
    timekey_wait 10m
  </buffer>
</match>
-->
```

---

## 📊 Querying Logs

### View Real-time Session Logs

```bash
# View all session logs
docker-compose logs -f backend | grep "session_id"

# View specific session
docker-compose logs -f backend | grep "550e8400-e29b-41d4-a716-446655440000"

# View only errors in sessions
docker-compose logs -f backend | grep "level.*ERROR" | grep "event_type.*error"

# View session summaries (session_end events)
docker-compose logs -f backend | grep "session_end"
```

### Parse with `jq`

```bash
# Extract translation latencies
docker-compose logs backend | grep "translation_completed" | jq -r '.latency_ms'

# Count errors by type
docker-compose logs backend | grep "event_type.*error" | jq -r '.event_type' | sort | uniq -c

# Get average STT latency
docker-compose logs backend | grep "stt_completed" | jq -r '.latency_ms' | \
  awk '{sum+=$1; count++} END {print "Avg:", sum/count "ms"}'

# Find sessions with high latency
docker-compose logs backend | grep "translation_completed" | \
  jq 'select(.latency_ms > 3000) | {session_id, user_id, latency_ms}'
```

### FluentD Log Files

```bash
# View logs stored by FluentD
docker-compose exec log_aggregator tail -f /fluentd/log/session.*.log

# Search in logs
docker-compose exec log_aggregator grep "error" /fluentd/log/session.*.log
```

---

## 📈 Performance Monitoring

### Session Metrics Endpoint (Admin)

```bash
# Get session metrics for user
curl -X GET "http://localhost:8000/api/v1/admin/sessions/123/metrics" \
  -H "Authorization: Bearer ADMIN_TOKEN"

# Response:
{
  "user_id": 123,
  "total_sessions": 45,
  "avg_session_duration": 300.5,
  "total_audio_bytes": 10485760,
  "avg_stt_latency_ms": 2100,
  "avg_translation_latency_ms": 1200,
  "stt_success_rate": 0.98,
  "translation_success_rate": 0.99,
  "unique_speakers": 3,
  "top_languages": ["vi", "en", "zh"]
}
```

### Real-time Dashboard Metrics (Future)

Once Prometheus integration added:

```prometheus
# Histogram for latencies
realtime_session_stt_latency_ms_bucket
realtime_session_translation_latency_ms_bucket

# Counters for events
realtime_session_events_total{event_type="stt_completed"}
realtime_session_errors_total{event_type="stt_error"}

# Gauge for active sessions
realtime_session_active{user_id="123"}
```

---

## 🛡️ Privacy & Security

### Sensitive Data Handling

The logging system automatically truncates sensitive information:

```python
# Only first 100 characters logged
"text": "Xin chào, bạn tên gì..."  # Full text never logged

# User IDs logged (needed for tracking)
"user_id": 123

# PII NOT logged:
# - Phone numbers
# - Email addresses
# - Full conversation content (only snippets)
# - Authentication tokens
```

### Log Retention Policy

```bash
SESSION_LOG_RETENTION_DAYS=30  # Older logs automatically deleted

# Manual cleanup
docker-compose exec log_aggregator \
  find /fluentd/log -mtime +30 -delete
```

---

## 🚨 Error Handling & Alerts

### Critical Error Conditions

Automatically logged at ERROR level:

- `STT_ERROR` - Speech recognition failed
- `TRANSLATION_ERROR` - Translation service down
- `SESSION_ERROR` - WebSocket connection lost
- `RATE_LIMIT_EXCEEDED` - User quota exceeded
- `AUDIO_BUFFER_OVERFLOW` - Too much data too fast

### Alert Configuration (Future)

```bash
# Alert if error rate exceeds threshold
ERROR_RATE_ALERT_THRESHOLD=0.05  # Alert if > 5% errors

# Example: If 100 translations, alert if > 5 fail
# Integrate with PagerDuty, Slack, email, etc.
```

---

## 🔧 Implementation in WebSocket Endpoint

```python
from app.services.realtime_session_logger import RealtimeSessionLogger, SessionEventType

# Create logger for session
session_logger = RealtimeSessionLogger(session_id="auto-generated-or-provided")

@router.websocket("/ws/conversation")
async def websocket_conversation(
    websocket: WebSocket,
    token: str = Query(...),
):
    user = await _authenticate_ws(websocket, token)
    await websocket.accept()
    
    # Log session start
    session_logger.log_event(
        event_type=SessionEventType.SESSION_START,
        user_id=user.id,
        details={"languages": f"{source_lang}→{target_lang}"}
    )
    
    try:
        while True:
            data = await websocket.receive()
            
            if "bytes" in data:
                # Audio chunk received
                chunk_size = len(data["bytes"])
                session_logger.log_audio_chunk(
                    user_id=user.id,
                    chunk_size=chunk_size,
                    sample_rate=16000,
                    channel=1
                )
            
            # Process STT
            start_time = time.time()
            try:
                stt_result = await stt_service.transcribe(audio)
                latency_ms = (time.time() - start_time) * 1000
                
                session_logger.log_stt_completed(
                    user_id=user.id,
                    text=stt_result["text"],
                    language=source_lang,
                    confidence=stt_result.get("confidence", 0.0),
                    latency_ms=latency_ms
                )
            except Exception as e:
                session_logger.log_stt_error(
                    user_id=user.id,
                    error_msg=str(e),
                    latency_ms=(time.time() - start_time) * 1000
                )
                continue
            
            # Process translation
            start_time = time.time()
            try:
                translation = await translate_service.translate(
                    stt_result["text"],
                    source_lang,
                    target_lang
                )
                latency_ms = (time.time() - start_time) * 1000
                
                session_logger.log_translation_completed(
                    user_id=user.id,
                    source_text=stt_result["text"],
                    translated_text=translation,
                    source_language=source_lang,
                    target_language=target_lang,
                    latency_ms=latency_ms
                )
                
                # Send result to client
                await websocket.send_json({
                    "event": "translation_result",
                    "stt_text": stt_result["text"],
                    "translated_text": translation,
                })
            
            except Exception as e:
                session_logger.log_translation_error(
                    user_id=user.id,
                    error_msg=str(e),
                    source_language=source_lang,
                    target_language=target_lang,
                    latency_ms=(time.time() - start_time) * 1000
                )
    
    except WebSocketDisconnect:
        session_logger.log_session_end(
            user_id=user.id,
            status="disconnected"
        )
    
    except Exception as e:
        session_logger.log_session_error(
            user_id=user.id,
            error_msg=str(e),
            error_code="CRITICAL"
        )
```

---

## 📊 Monitoring & Alerting

### Key Metrics to Monitor

1. **Success Rates** (should be > 95%)
   - STT success rate
   - Translation success rate
   - Session completion rate

2. **Latencies** (should be < 3 seconds)
   - STT processing time
   - Translation processing time
   - End-to-end latency

3. **Error Rates** (should be < 5%)
   - STT errors per session
   - Translation errors per session
   - Network connection errors

4. **Resource Usage**
   - Average session duration
   - Bytes received/transmitted
   - Active concurrent sessions

---

## 🚀 Production Deployment Checklist

- [ ] FluentD configured and running
- [ ] Session logging enabled in `.env`
- [ ] Log retention policy set (30+ days)
- [ ] Log aggregation backend ready (Elasticsearch, S3, etc.)
- [ ] Alert thresholds configured
- [ ] PII filtering enabled
- [ ] Log rotation configured
- [ ] Monitoring dashboards created
- [ ] Alert channels configured (Slack, email, PagerDuty)

---

## 📞 Support

- View logs: `docker-compose logs -f backend | grep session`
- Query FluentD: `docker-compose exec log_aggregator tail -f /fluentd/log/`
- API docs: `http://localhost:8080/docs`
- Admin dashboard: `http://localhost:8080/admin`

