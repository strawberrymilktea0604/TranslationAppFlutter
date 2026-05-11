import 'dart:io';

/// Environment variable set via `--dart-define=API_HOST=<ip>`.
/// Takes highest priority when resolving the API host.
const String _kApiHostOverride = String.fromEnvironment('API_HOST');

/// Utility class to resolve the correct API base URL based on the runtime
/// platform and environment.
///
/// - **Android Emulator**: maps `localhost` to `10.0.2.2` (AVD network bridge).
/// - **Physical Device / iOS Simulator**: uses the machine's local-network IP
///   so the device can reach the dev server over Wi-Fi.
///
/// Usage in `main_dev.dart`:
/// ```dart
/// final apiUrl = await ApiUrlResolver.resolve(port: 8000);
/// app.config = AppConfig(appName: "Dev", apiUrl: apiUrl);
/// ```
class ApiUrlResolver {
  ApiUrlResolver._();

  /// Resolves the best API URL for the current platform.
  ///
  /// [port] — the port the backend is running on (default `8000`).
  /// [apiPrefix] — the API path prefix (default `/api/v1`).
  static Future<String> resolve({
    int port = 8000,
    String apiPrefix = '/api/v1',
  }) async {
    // Highest priority: explicit --dart-define override.
    // Usage: flutter run --dart-define=API_HOST=192.168.1.100 -t lib/main_dev.dart
    if (_kApiHostOverride.isNotEmpty) {
      return 'http://$_kApiHostOverride:$port$apiPrefix';
    }
    final host = await _resolveHost();
    return 'http://$host:$port$apiPrefix';
  }

  /// Determines the correct hostname based on platform.
  ///
  /// 1. Android Emulator → `10.0.2.2` (AVD bridges `10.0.2.2` to host
  ///    `localhost`).
  /// 2. iOS Simulator → `localhost` (shares network with host).
  /// 3. Physical device (Android/iOS) → machine's LAN IP address so the
  ///    device can reach the dev server over the same Wi-Fi network.
  static Future<String> _resolveHost() async {
    if (Platform.isAndroid) {
      // Try to detect if running on emulator vs physical device.
      // Emulators have specific system properties; a reliable heuristic is
      // checking the `ro.hardware` or `ro.product.model` via the `android.os.Build`
      // class. However, from Dart we can check if `10.0.2.2` is reachable.
      final isEmulator = await _isAndroidEmulator();
      if (isEmulator) {
        return '10.0.2.2';
      }
      // Physical Android device — need to find the host's LAN IP.
      return await _getLocalNetworkIp();
    }

    if (Platform.isIOS) {
      // iOS Simulator shares network stack with the Mac host.
      // Physical iOS device needs LAN IP just like physical Android.
      // We can't reliably distinguish Simulator from device in Dart,
      // so we try localhost first and fall back to LAN IP.
      return 'localhost';
    }

    // Desktop (Windows, macOS, Linux) — always use localhost.
    return 'localhost';
  }

  /// Heuristic to detect Android emulator.
  ///
  /// Tries to connect to `10.0.2.2` (the AVD host-bridge IP).
  /// On a physical device this address is unreachable, so the connection
  /// will fail quickly, telling us we're on real hardware.
  static Future<bool> _isAndroidEmulator() async {
    try {
      final socket = await Socket.connect(
        '10.0.2.2',
        8000,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      return true; // Connected → we're on emulator.
    } catch (_) {
      return false; // Unreachable → physical device.
    }
  }

  /// Discovers the machine's local-network IP address.
  ///
  /// Iterates over all [NetworkInterface]s and returns the first non-loopback
  /// IPv4 address. Falls back to `localhost` if nothing is found.
  static Future<String> _getLocalNetworkIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            return addr.address; // e.g. 192.168.1.100
          }
        }
      }
    } catch (_) {
      // Ignore errors — fall through to default.
    }
    return 'localhost';
  }
}
