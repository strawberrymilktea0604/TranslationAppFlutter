import 'dart:async';
import 'dart:convert';
import 'package:web_socket_mock/web_socket_mock.dart';

/// Mock WebSocket Server for Conversation Testing
/// Simulates real WebSocket communication without needing backend
class MockWebSocketServer {
  final _streams = <String, StreamController<dynamic>>{};
  final _connections = <String, WebSocketMock>{};
  bool _isRunning = false;

  /// Start mock WebSocket server
  void start() {
    _isRunning = true;
  }

  /// Stop mock WebSocket server
  void stop() {
    _isRunning = false;
    for (final stream in _streams.values) {
      stream.close();
    }
    _streams.clear();
    _connections.clear();
  }

  /// Create mock connection
  WebSocketMock createMockConnection(String url) {
    if (!_isRunning) {
      throw Exception('WebSocket server not running');
    }

    final streamController = StreamController<dynamic>.broadcast();
    final mockSocket = WebSocketMock(url, streamController);

    _streams[url] = streamController;
    _connections[url] = mockSocket;

    // Simulate connection opened
    Future.delayed(Duration(milliseconds: 100), () {
      mockSocket.simulateOpen();
    });

    return mockSocket;
  }

  /// Simulate receiving a message
  void simulateMessage(String url, Map<String, dynamic> message) {
    final stream = _streams[url];
    if (stream != null) {
      stream.add(jsonEncode(message));
    }
  }

  /// Simulate connection error
  void simulateError(String url, String error) {
    final stream = _streams[url];
    if (stream != null) {
      stream.addError(Exception(error));
    }
  }

  /// Simulate connection close
  void simulateClose(String url, [int code = 1000, String reason = '']) {
    final connection = _connections[url];
    if (connection != null) {
      connection.simulateClose(code, reason);
    }
  }

  /// Get mock connection
  WebSocketMock? getConnection(String url) => _connections[url];

  /// Check if connection exists
  bool hasConnection(String url) => _connections.containsKey(url);

  /// Get all active connections
  Map<String, WebSocketMock> getActiveConnections() =>
      Map.from(_connections);

  /// Get connection count
  int getConnectionCount() => _connections.length;
}

// ==================== Mock WebSocket Implementation ====================

/// Simulates WebSocket for message-based communication
class MockConversationWebSocket {
  final String conversationId;
  final String targetLanguage;
  late StreamController<ConversationMessage> _messageController;
  late Stream<ConversationMessage> messageStream;
  bool _connected = false;

  MockConversationWebSocket({
    required this.conversationId,
    required this.targetLanguage,
  }) {
    _messageController = StreamController<ConversationMessage>.broadcast();
    messageStream = _messageController.stream;
  }

  /// Simulate connection
  Future<void> connect() async {
    await Future.delayed(Duration(milliseconds: 100));
    _connected = true;
  }

  /// Simulate disconnect
  Future<void> disconnect() async {
    _connected = false;
    await _messageController.close();
  }

  /// Simulate receiving a translated message
  void simulateReceivedMessage(
    String userMessage,
    String translatedResponse,
    String speakerUrl,
  ) {
    if (_connected) {
      _messageController.add(
        ConversationMessage(
          userMessage: userMessage,
          translatedResponse: translatedResponse,
          speakerUrl: speakerUrl,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Simulate receiving an error
  void simulateError(String error) {
    if (_connected) {
      _messageController.addError(Exception(error));
    }
  }

  /// Check connection status
  bool get isConnected => _connected;

  /// Close the stream
  void close() {
    _messageController.close();
  }
}

/// Model for conversation messages
class ConversationMessage {
  final String userMessage;
  final String translatedResponse;
  final String speakerUrl;
  final DateTime timestamp;

  ConversationMessage({
    required this.userMessage,
    required this.translatedResponse,
    required this.speakerUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'user_message': userMessage,
    'translated_response': translatedResponse,
    'speaker_url': speakerUrl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ConversationMessage.fromJson(Map<String, dynamic> json) =>
      ConversationMessage(
        userMessage: json['user_message'] as String,
        translatedResponse: json['translated_response'] as String,
        speakerUrl: json['speaker_url'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

// ==================== Mock Server Responses ====================

/// Predefined mock responses for testing
class MockWebSocketResponses {
  /// Mock response for conversation start
  static Map<String, dynamic> conversationStarted(int conversationId) => {
    'type': 'conversation_started',
    'conversation_id': conversationId,
    'status': 'active',
    'timestamp': DateTime.now().toIso8601String(),
  };

  /// Mock response for message received
  static Map<String, dynamic> messageReceived(
    int conversationId,
    String userMessage,
    String translatedResponse,
    String speakerUrl,
  ) =>
      {
        'type': 'message_received',
        'conversation_id': conversationId,
        'user_message': userMessage,
        'translated_response': translatedResponse,
        'speaker_url': speakerUrl,
        'timestamp': DateTime.now().toIso8601String(),
      };

  /// Mock response for conversation ended
  static Map<String, dynamic> conversationEnded(int conversationId) => {
    'type': 'conversation_ended',
    'conversation_id': conversationId,
    'status': 'closed',
    'timestamp': DateTime.now().toIso8601String(),
  };

  /// Mock error response
  static Map<String, dynamic> errorResponse(
    String errorCode,
    String message,
  ) =>
      {
        'type': 'error',
        'error_code': errorCode,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

  /// Mock response for invalid token
  static Map<String, dynamic> unauthorizedResponse() => {
    'type': 'error',
    'error_code': '401',
    'message': 'Unauthorized - invalid token',
    'timestamp': DateTime.now().toIso8601String(),
  };

  /// Mock response for permission denied
  static Map<String, dynamic> forbiddenResponse() => {
    'type': 'error',
    'error_code': '403',
    'message': 'Forbidden - insufficient permissions',
    'timestamp': DateTime.now().toIso8601String(),
  };

  /// Mock response for server error
  static Map<String, dynamic> serverErrorResponse() => {
    'type': 'error',
    'error_code': '500',
    'message': 'Internal server error',
    'timestamp': DateTime.now().toIso8601String(),
  };

  /// Mock response for connection timeout
  static Map<String, dynamic> timeoutResponse() => {
    'type': 'error',
    'error_code': 'TIMEOUT',
    'message': 'Connection timeout',
    'timestamp': DateTime.now().toIso8601String(),
  };

  /// Mock response for rate limit exceeded
  static Map<String, dynamic> rateLimitExceededResponse() => {
    'type': 'error',
    'error_code': '429',
    'message': 'Too many requests - rate limit exceeded',
    'timestamp': DateTime.now().toIso8601String(),
  };
}

// ==================== Test Utilities ====================

/// Helper to simulate common scenarios
class MockConversationScenarios {
  /// Simulate successful conversation flow
  static Future<void> simulateSuccessfulConversation(
    MockConversationWebSocket socket,
    List<String> messages,
  ) async {
    for (final message in messages) {
      await Future.delayed(Duration(milliseconds: 200));
      socket.simulateReceivedMessage(
        message,
        _mockTranslate(message),
        'https://example.com/audio/${message.hashCode}.mp3',
      );
    }
  }

  /// Simulate network error during conversation
  static Future<void> simulateNetworkError(
    MockConversationWebSocket socket,
  ) async {
    await Future.delayed(Duration(milliseconds: 500));
    socket.simulateError('Network error: connection lost');
  }

  /// Simulate timeout
  static Future<void> simulateTimeout(
    MockConversationWebSocket socket,
  ) async {
    await Future.delayed(Duration(seconds: 2));
    socket.simulateError('Request timeout after 30 seconds');
  }

  /// Simulate server error
  static Future<void> simulateServerError(
    MockConversationWebSocket socket,
  ) async {
    await Future.delayed(Duration(milliseconds: 300));
    socket.simulateError('Server error: 500 Internal Server Error');
  }

  static String _mockTranslate(String message) {
    const translations = {
      'hello': 'Xin chào',
      'good morning': 'Chào buổi sáng',
      'how are you': 'Bạn khỏe không',
      'thank you': 'Cảm ơn',
      'goodbye': 'Tạm biệt',
    };
    return translations[message.toLowerCase()] ?? 'Dịch: $message';
  }
}
