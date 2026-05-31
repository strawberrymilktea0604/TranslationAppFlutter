# WebSocket Configuration Guide

**Status:** ✅ Production Ready  
**Last Updated:** May 24, 2026  
**WebSocket Endpoints:**
- `/api/v1/ws` - Sync notifications (vocabulary & translation history)
- `/api/v1/ws/conversation` - Real-time voice translation

---

## 📋 WebSocket Features Overview

### 1. **Sync Notifications WebSocket** (`/api/v1/ws`)
Provides real-time push notifications when vocabulary or translation history syncs complete.

**Protocol:**
```
Client: POST /api/v1/sync (sync data)
Server: Sends via WebSocket → {"event": "sync_completed", "synced_count": 50, ...}
Client: Updates local Isar database with sync badge
```

**Use Cases:**
- Notify Flutter app when background sync completes
- Real-time indicator in "History" and "Vocabulary" tabs
- Per-device sync status tracking

### 2. **Conversation WebSocket** (`/api/v1/ws/conversation`)
Real-time voice translation pipeline with streaming audio support.

**Protocol:**
```
Client: ws://backend/api/v1/ws/conversation?token=ACCESS_TOKEN
Client → Server: Binary audio chunks (16kHz mono PCM)
Server: STT → Translation → Response
Server → Client: {"event": "translation_result", "text": "...", ...}
```

**Use Cases:**
- Real-time voice chat translation
- Multi-speaker conversation tracking
- Live transcription with translation

---

## ⚙️ Environment Variables

### Add to `.env`

```bash
# ==========================================
# WEBSOCKET CONFIGURATION
# ==========================================

# Connection settings
WEBSOCKET_ENABLED=true
WEBSOCKET_PING_INTERVAL=30  # seconds - keepalive ping to detect dead connections
WEBSOCKET_PING_TIMEOUT=10   # seconds - wait for pong response
WEBSOCKET_CONNECTION_TIMEOUT=30  # seconds - timeout for initial connection

# Buffer and Queue sizes
WEBSOCKET_MAX_CONNECTIONS_PER_USER=5  # Multiple browser tabs/devices
WEBSOCKET_MESSAGE_QUEUE_SIZE=100  # Messages queued if client slow
WEBSOCKET_BUFFER_SIZE=1024  # KB - TCP buffer

# Conversation-specific settings
CONVERSATION_SESSION_TIMEOUT=300  # seconds - 5 min idle timeout
CONVERSATION_SEGMENT_TIMEOUT=10   # seconds - end utterance if no audio for 10s
CONVERSATION_MAX_AUDIO_SIZE=50  # MB - max audio file size per session
CONVERSATION_MAX_SESSIONS_PER_USER=3  # Concurrent conversations

# Audio streaming settings
AUDIO_CHUNK_SIZE=4096  # bytes per chunk (16kHz * 2 bytes * 0.128s)
AUDIO_SAMPLE_RATE=16000  # Hz - must match client
AUDIO_CHANNELS=1  # mono
AUDIO_FORMAT="pcm_s16le"  # format: pcm_s16le, wav, m4a, etc.

# Connection pool (for backend WebSocket clients)
WEBSOCKET_POOL_SIZE=100  # Max concurrent WS connections to handle

# Logging
WEBSOCKET_LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR

# Error handling
WEBSOCKET_AUTO_RECONNECT_ENABLED=true
WEBSOCKET_RECONNECT_DELAY_SECONDS=3
WEBSOCKET_MAX_RECONNECT_ATTEMPTS=10

# Rate limiting for WebSocket (per user per minute)
WEBSOCKET_MESSAGE_RATE_LIMIT=1000  # messages per minute
WEBSOCKET_AUDIO_RATE_LIMIT_MB=50   # MB per minute
```

### Environment-Specific Configurations

#### Development

```bash
WEBSOCKET_ENABLED=true
WEBSOCKET_PING_INTERVAL=60  # Less frequent pings
WEBSOCKET_PING_TIMEOUT=30
WEBSOCKET_CONNECTION_TIMEOUT=60
WEBSOCKET_MAX_CONNECTIONS_PER_USER=10  # Allow testing
CONVERSATION_SESSION_TIMEOUT=3600  # 1 hour for debugging
WEBSOCKET_LOG_LEVEL=DEBUG
WEBSOCKET_MAX_RECONNECT_ATTEMPTS=20
```

#### Staging

```bash
WEBSOCKET_ENABLED=true
WEBSOCKET_PING_INTERVAL=45
WEBSOCKET_PING_TIMEOUT=15
WEBSOCKET_CONNECTION_TIMEOUT=45
WEBSOCKET_MAX_CONNECTIONS_PER_USER=5
CONVERSATION_SESSION_TIMEOUT=600  # 10 min
WEBSOCKET_LOG_LEVEL=INFO
```

#### Production

```bash
WEBSOCKET_ENABLED=true
WEBSOCKET_PING_INTERVAL=30  # Aggressive keepalive
WEBSOCKET_PING_TIMEOUT=10
WEBSOCKET_CONNECTION_TIMEOUT=30
WEBSOCKET_MAX_CONNECTIONS_PER_USER=3
CONVERSATION_SESSION_TIMEOUT=300  # 5 min strict timeout
WEBSOCKET_MESSAGE_RATE_LIMIT=500  # Anti-abuse
WEBSOCKET_AUDIO_RATE_LIMIT_MB=25
WEBSOCKET_LOG_LEVEL=WARNING
```

---

## 🔧 Nginx Configuration for WebSocket

### Update `nginx.conf` for WebSocket Support

The nginx configuration has been updated to support WebSocket connections:

```nginx
# Already configured in your nginx.conf:

location /api/ {
    proxy_pass http://backend;
    
    # WebSocket support
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # Timeouts for long-running connections
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}
```

**Key settings:**
- `proxy_http_version 1.1` - Required for WebSocket upgrade
- `Upgrade` header - Signals WebSocket upgrade
- `Connection: upgrade` - Enables protocol upgrade
- `proxy_read_timeout 60s` - Prevents timeout during long idle periods

---

## 🔌 Client Implementation (Flutter)

### Connect to Sync Notifications WebSocket

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> connectSyncWebSocket(String token) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8080/api/v1/ws?token=$token'),
  );

  // Listen for events
  channel.stream.listen(
    (message) {
      final event = jsonDecode(message);
      
      if (event['event'] == 'sync_completed') {
        print('Synced ${event['synced_count']} items');
        // Trigger local Isar database reload
      }
    },
    onDone: () => print('Sync WS closed'),
    onError: (error) => print('Error: $error'),
  );

  // Send keepalive ping periodically
  Timer.periodic(Duration(seconds: 30), (_) {
    channel.sink.add(jsonEncode({'ping': true}));
  });
}
```

### Connect to Conversation WebSocket

```dart
Future<void> connectConversationWebSocket(String token) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8080/api/v1/ws/conversation?token=$token'),
  );

  // Start session
  channel.sink.add(jsonEncode({
    'event': 'session_start',
    'source_language': 'vi',
    'target_language': 'en',
    'speaker': 'SPEAKER_A',
  }));

  // Stream audio chunks (16kHz mono PCM)
  final audioData = <int>[...]; // 16-bit PCM bytes
  channel.sink.addStream(Stream.fromIterable([audioData]));

  // End utterance for processing
  channel.sink.add(jsonEncode({
    'event': 'end_utterance',
  }));

  // Listen for translation results
  channel.stream.listen((message) {
    final event = jsonDecode(message);
    
    if (event['event'] == 'translation_result') {
      print('STT: ${event['stt_text']}');
      print('Translation: ${event['translated_text']}');
    }
  });

  // End session
  channel.sink.add(jsonEncode({'event': 'session_end'}));
}
```

---

## 🔐 Authentication & Security

### Token Validation

All WebSocket connections require a valid JWT access token:

```bash
# Connect with token
ws://backend:8080/api/v1/ws?token=<ACCESS_TOKEN>

# Token validation checks:
1. JWT signature valid (using SECRET_KEY)
2. Token not expired
3. Token type is "access" (not "refresh")
4. Token JTI not revoked
5. User exists and is active
```

### Connection Limits

Each user can have multiple WebSocket connections (different tabs/devices):

```bash
WEBSOCKET_MAX_CONNECTIONS_PER_USER=3

# Exceeding limit → new connection rejected with code 1008 (Policy Violation)
```

---

## 📊 Monitoring & Debugging

### Check WebSocket Status

```bash
# Check if WebSocket endpoint is reachable
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
  -H "Sec-WebSocket-Version: 13" \
  http://localhost:8080/api/v1/ws?token=YOUR_TOKEN

# Response should have status 101 Switching Protocols
```

### View WebSocket Logs

```bash
# All WebSocket events
docker-compose logs -f backend | grep "WS"

# Specific connection logs
docker-compose logs -f backend | grep "user_id=123"

# Debug conversation sessions
docker-compose logs -f backend | grep "conversation"
```

### Monitor Active Connections

```bash
# Number of active WebSocket connections (via metrics endpoint)
curl http://localhost:8000/api/v1/admin/websocket/status

# Response:
{
  "total_connections": 15,
  "by_user": {
    "1": 2,  # User 1 has 2 connections
    "5": 1,
    ...
  },
  "by_type": {
    "sync": 12,
    "conversation": 3
  }
}
```

---

## 🛡️ Performance Optimization

### Connection Pooling

Backend uses connection pooling to handle concurrent WebSocket clients:

```bash
WEBSOCKET_POOL_SIZE=100  # Handle 100+ concurrent connections

# If exceeded, new connections queued with short timeout
```

### Audio Buffering

For real-time voice translation:

```bash
# Optimal chunk size for 16kHz mono:
AUDIO_CHUNK_SIZE=4096  # bytes ≈ 128ms of audio

# Adjustments:
- Smaller chunks (2048) → lower latency, more overhead
- Larger chunks (8192) → higher latency, less overhead
```

### Message Batching

For sync notifications with many items:

```python
# Server batches sync completion into single message
{
  "event": "sync_completed",
  "synced_count": 500,  # All synced items in one notification
  "timestamp": "2026-05-24T12:00:00Z"
}

# Client processes once → updates local DB
```

---

## 🚨 Error Handling

### WebSocket Close Codes

```
1000 (Normal Closure)
  - Graceful disconnect, user-initiated

1006 (Abnormal Closure)
  - Connection lost, network error, timeout

1008 (Policy Violation)
  - Auth failed, token revoked, limit exceeded

1009 (Message Too Big)
  - Audio chunk exceeds WEBSOCKET_BUFFER_SIZE

1011 (Server Error)
  - Unhandled exception, service unavailable
```

### Client Reconnection Logic

```dart
// Recommended client reconnection strategy:
final maxRetries = 10;
final delaySeconds = 3;

Future<void> connectWithRetry() async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      await connect();
      break;  // Success
    } catch (e) {
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }
}
```

---

## 🔧 Docker Compose WebSocket Setup

WebSocket support is already configured in `docker-compose.yml`:

```yaml
services:
  nginx:
    environment:
      - WEBSOCKET_ENABLED=true
    
  backend:
    # WebSocket inherits from environment
    depends_on:
      - redis  # For session management
      - db     # For user auth
```

---

## 📝 Example: Full Conversation Flow

### 1. Client Initiates

```bash
# Client opens WebSocket with token
WS ws://backend:8080/api/v1/ws/conversation?token=abc123

# Server accepts and waits for session_start
```

### 2. Start Session

```json
{
  "event": "session_start",
  "source_language": "vi",
  "target_language": "en",
  "speaker": "SPEAKER_A"
}
```

### 3. Stream Audio

```
[Binary Audio Data] → 16kHz mono PCM chunks
```

### 4. End Utterance

```json
{
  "event": "end_utterance"
}
```

### 5. Receive Translation

```json
{
  "event": "translation_result",
  "stt_text": "Xin chào",
  "translated_text": "Hello",
  "source_language": "vi",
  "target_language": "en",
  "speaker": "SPEAKER_A",
  "confidence": 0.95,
  "duration_seconds": 1.5
}
```

### 6. End Session

```json
{
  "event": "session_end"
}
```

---

## 🚀 Production Deployment Checklist

- [ ] WebSocket enabled in `.env`
- [ ] Nginx WebSocket headers configured (already done)
- [ ] Ping interval set appropriately (30s production)
- [ ] Connection limit per user set (3-5 typical)
- [ ] Session timeout configured (300s production)
- [ ] Rate limiting enabled for WebSocket messages
- [ ] Monitoring/alerting set up for WebSocket errors
- [ ] Load balancer supports sticky sessions (if distributed)
- [ ] Firewall allows WebSocket ports (80/443)
- [ ] Redis available for session management

---

## 📞 Troubleshooting

| Issue | Solution |
|-------|----------|
| **Connection refused** | Check Nginx WebSocket headers, backend running |
| **Connection timeout** | Check WEBSOCKET_CONNECTION_TIMEOUT setting |
| **Frequent disconnects** | Increase WEBSOCKET_PING_INTERVAL or check network |
| **No audio transmission** | Verify AUDIO_SAMPLE_RATE=16000, PCM format |
| **Memory leak** | Check connection cleanup on disconnect |
| **High latency** | Reduce AUDIO_CHUNK_SIZE for lower latency |

---

## 📖 References

- [WebSocket Protocol (RFC 6455)](https://tools.ietf.org/html/rfc6455)
- [FastAPI WebSocket Docs](https://fastapi.tiangolo.com/advanced/websockets/)
- [Nginx WebSocket Proxying](https://nginx.org/en/docs/http/websocket.html)
- [Flutter WebSocket Package](https://pub.dev/packages/web_socket_channel)

