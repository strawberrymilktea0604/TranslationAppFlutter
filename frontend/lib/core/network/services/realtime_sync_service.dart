import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web_socket_channel/web_socket_channel.dart';

/// Event emitted by [RealtimeSyncService] when the server confirms
/// that a batch sync completed.
class SyncCompletedEvent {
  final int syncedCount;
  final DateTime timestamp;

  const SyncCompletedEvent({
    required this.syncedCount,
    required this.timestamp,
  });
}

/// Manages the WebSocket connection to the backend for realtime sync events.
///
/// Protocol: RFC 6455 (WebSocket protocol version 13).
/// Server endpoint: `ws(s)://<host>/api/v1/ws?token=<access_token>`
///
/// The service:
/// 1. Opens a WS connection with the access token as a query param.
/// 2. Sends keepalive pings every [_pingInterval].
/// 3. On receiving a `sync_completed` event, emits to [syncEvents].
/// 4. Auto-reconnects after [_reconnectDelay] on disconnect.
class RealtimeSyncService {
  final String _baseWsUrl;

  RealtimeSyncService({required String baseApiUrl})
      : _baseWsUrl = baseApiUrl
            .replaceFirst(RegExp(r'^http'), 'ws')
            .replaceFirst(RegExp(r'/api/v1$'), '/api/v1');

  // Public stream of sync events.
  final _controller = StreamController<SyncCompletedEvent>.broadcast();
  Stream<SyncCompletedEvent> get syncEvents => _controller.stream;

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  String? _currentToken;

  static const _pingInterval = Duration(seconds: 25);
  static const _reconnectDelay = Duration(seconds: 5);

  /// Connect (or reconnect) to the WebSocket endpoint.
  ///
  /// Call this after login / when the access token is refreshed.
  Future<void> connect(String accessToken) async {
    _currentToken = accessToken;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed || _currentToken == null) return;

    _cancelTimers();
    await _channel?.sink.close();

    final uri = Uri.parse('$_baseWsUrl/ws?token=$_currentToken');
    developer.log('WS connecting to $uri', name: 'RealtimeSyncService');

    try {
      _channel = WebSocketChannel.connect(uri);

      // Listen for messages from the server.
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Start keepalive pings.
      _pingTimer = Timer.periodic(_pingInterval, (_) {
        try {
          _channel?.sink.add(jsonEncode({'ping': true}));
        } catch (_) {}
      });

      developer.log('WS connected', name: 'RealtimeSyncService');
    } catch (e) {
      developer.log('WS connect error: $e', name: 'RealtimeSyncService');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;

      if (data['event'] == 'sync_completed') {
        final event = SyncCompletedEvent(
          syncedCount: (data['synced_count'] as num?)?.toInt() ?? 0,
          timestamp: data['timestamp'] != null
              ? DateTime.parse(data['timestamp'] as String)
              : DateTime.now(),
        );
        developer.log(
          'WS sync_completed: ${event.syncedCount} items',
          name: 'RealtimeSyncService',
        );
        if (!_controller.isClosed) {
          _controller.add(event);
        }
      }
      // pong responses are silently ignored.
    } catch (e) {
      developer.log('WS parse error: $e', name: 'RealtimeSyncService');
    }
  }

  void _onError(Object error) {
    developer.log('WS error: $error', name: 'RealtimeSyncService');
    _scheduleReconnect();
  }

  void _onDone() {
    developer.log('WS disconnected', name: 'RealtimeSyncService');
    if (!_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _cancelTimers();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_disposed) _doConnect();
    });
    developer.log(
      'WS will reconnect in ${_reconnectDelay.inSeconds}s',
      name: 'RealtimeSyncService',
    );
  }

  void _cancelTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Disconnect cleanly (e.g. on logout).
  Future<void> disconnect() async {
    _cancelTimers();
    await _channel?.sink.close();
    _channel = null;
    _currentToken = null;
    developer.log('WS disconnected by app', name: 'RealtimeSyncService');
  }

  /// Dispose — call when the service is no longer needed.
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _controller.close();
  }
}
