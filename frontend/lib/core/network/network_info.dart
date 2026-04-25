import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Abstract interface for checking network connectivity.
/// Used by repositories to determine offline/online strategy.
abstract class NetworkInfo {
  Future<bool> get isConnected;

  /// Stream providing continuous updates on network internet access status
  Stream<bool> get onConnectedChange;
}

/// Implementation of [NetworkInfo] using [InternetConnection].
///
/// Verifies real internet access by pinging DNS servers,
/// not just checking WiFi/mobile data availability.
/// Registered as a lazy singleton via GetIt in [injection_container].
class NetworkInfoImpl implements NetworkInfo {
  final InternetConnection connectionChecker;

  const NetworkInfoImpl(this.connectionChecker);

  @override
  Future<bool> get isConnected => connectionChecker.hasInternetAccess;

  @override
  Stream<bool> get onConnectedChange =>
      connectionChecker.onStatusChange.map((status) {
        return status == InternetStatus.connected;
      });
}
