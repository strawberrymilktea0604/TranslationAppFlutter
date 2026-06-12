import 'dart:async';

import 'package:http/http.dart' as http;

Uri backendHealthUri(String apiUrl) {
  final normalized = apiUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  return Uri.parse('$normalized/health');
}

/// Abstract interface for checking network connectivity.
/// Used by repositories to determine offline/online strategy.
abstract class NetworkInfo {
  Future<bool> get isConnected;

  /// Stream providing continuous updates on network internet access status
  Stream<bool> get onConnectedChange;
}

/// Implementation of [NetworkInfo] using the backend health endpoint.
/// Registered as a lazy singleton via GetIt in [injection_container].
class NetworkInfoImpl implements NetworkInfo {
  final http.Client client;
  final Uri healthUri;
  final Duration timeout;
  final Duration checkInterval;

  const NetworkInfoImpl({
    required this.client,
    required this.healthUri,
    this.timeout = const Duration(seconds: 3),
    this.checkInterval = const Duration(seconds: 5),
  });

  @override
  Future<bool> get isConnected => _checkHealth();

  @override
  Stream<bool> get onConnectedChange =>
      Stream.periodic(checkInterval).asyncMap((_) => _checkHealth()).distinct();

  Future<bool> _checkHealth() async {
    try {
      final response = await client.get(healthUri).timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }
}
