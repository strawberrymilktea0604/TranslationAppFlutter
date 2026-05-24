import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';

/// Interface for the conversation WebSocket data source.
///
/// Wraps the `web_socket_channel` package behind an abstraction so the
/// repository (and transitively the Cubit) does not depend on the plugin
/// directly.
abstract class ConversationRemoteDataSource {
  /// Opens a WebSocket connection to the conversation endpoint.
  ///
  /// [wsUrl] — full WS URL including token query param.
  void connect(String wsUrl);

  /// Sends a JSON text frame.
  void sendJson(Map<String, dynamic> data);

  /// Sends raw binary audio data as a binary frame.
  void sendBytes(Uint8List data);

  /// Stream of raw messages (String for text frames, Uint8List for binary).
  Stream<dynamic> get messageStream;

  /// Current connection status.
  WebSocketConnectionStatus get connectionStatus;

  /// Stream of connection status changes.
  Stream<WebSocketConnectionStatus> get statusStream;

  /// Closes the WebSocket connection gracefully.
  Future<void> disconnect();

  /// Disposes all resources.
  Future<void> dispose();
}

/// Implementation of [ConversationRemoteDataSource] using `web_socket_channel`.
///
/// Features:
/// - Keepalive pings every [_pingInterval].
/// - Auto-reconnect after [_reconnectDelay] on unexpected disconnect.
/// - Broadcast stream controller for multiple listeners.
///
/// Modeled after the existing [RealtimeSyncService] in the project.
class ConversationRemoteDataSourceImpl implements ConversationRemoteDataSource {
  static const _tag = 'ConversationWS';
  static const _pingInterval = Duration(seconds: 25);
  static const _reconnectDelay = Duration(seconds: 5);
  static const _maxReconnectAttempts = 5;

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  String? _currentUrl;
  int _reconnectAttempts = 0;

  WebSocketConnectionStatus _status = WebSocketConnectionStatus.disconnected;

  final _messageController = StreamController<dynamic>.broadcast();
  final _statusController =
      StreamController<WebSocketConnectionStatus>.broadcast();

  @override
  WebSocketConnectionStatus get connectionStatus => _status;

  @override
  Stream<dynamic> get messageStream => _messageController.stream;

  /// Stream of connection status changes.
  @override
  Stream<WebSocketConnectionStatus> get statusStream =>
      _statusController.stream;

  @override
  void connect(String wsUrl) {
    _currentUrl = wsUrl;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void _doConnect() {
    if (_disposed || _currentUrl == null) return;

    _cancelTimers();
    _setStatus(WebSocketConnectionStatus.connecting);

    final uri = Uri.parse(_currentUrl!);
    developer.log('Connecting to $uri', name: _tag);

    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Start keepalive pings.
      _pingTimer = Timer.periodic(_pingInterval, (_) {
        try {
          _channel?.sink.add(jsonEncode({'event': 'ping'}));
        } catch (_) {}
      });

      _setStatus(WebSocketConnectionStatus.connected);
      _reconnectAttempts = 0;
      developer.log('Connected', name: _tag);
    } catch (e) {
      developer.log('Connection error: $e', name: _tag);
      _setStatus(WebSocketConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (_messageController.isClosed) return;
    _messageController.add(raw);
  }

  void _onError(Object error) {
    developer.log('Error: $error', name: _tag);
    _setStatus(WebSocketConnectionStatus.error);
    _scheduleReconnect();
  }

  void _onDone() {
    developer.log('Disconnected', name: _tag);
    if (!_disposed) {
      _setStatus(WebSocketConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      developer.log(
        'Max reconnect attempts reached ($_maxReconnectAttempts)',
        name: _tag,
      );
      _setStatus(WebSocketConnectionStatus.error);
      return;
    }

    _cancelTimers();
    _setStatus(WebSocketConnectionStatus.reconnecting);
    _reconnectAttempts++;

    final delay = _reconnectDelay * _reconnectAttempts;
    developer.log(
      'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
      name: _tag,
    );

    _reconnectTimer = Timer(delay, () {
      if (!_disposed) _doConnect();
    });
  }

  void _setStatus(WebSocketConnectionStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void _cancelTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  @override
  void sendJson(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      developer.log('sendJson error: $e', name: _tag);
    }
  }

  @override
  void sendBytes(Uint8List data) {
    try {
      _channel?.sink.add(data);
    } catch (e) {
      developer.log('sendBytes error: $e', name: _tag);
    }
  }

  @override
  Future<void> disconnect() async {
    _cancelTimers();
    _reconnectAttempts = _maxReconnectAttempts; // prevent auto-reconnect
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _currentUrl = null;
    _setStatus(WebSocketConnectionStatus.disconnected);
    developer.log('Disconnected by app', name: _tag);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messageController.close();
    await _statusController.close();
  }
}
