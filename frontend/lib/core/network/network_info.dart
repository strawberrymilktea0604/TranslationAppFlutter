/// Abstract interface for checking network connectivity.
/// Used by repositories to determine offline/online strategy.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}
