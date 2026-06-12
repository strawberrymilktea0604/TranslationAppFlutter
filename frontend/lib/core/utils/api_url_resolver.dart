import 'dart:async';
import 'dart:developer';
import 'dart:io';

/// Full API base URL set via `--dart-define=API_BASE_URL=<url>`.
/// Takes highest priority when resolving the API URL.
const String _kApiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

/// API host override set via `--dart-define=API_HOST=<ip>`.
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
    if (_kApiBaseUrlOverride.isNotEmpty) {
      return _apiUrlFromBase(_kApiBaseUrlOverride, apiPrefix);
    }

    // Highest priority: explicit --dart-define override.
    // Usage: flutter run --dart-define=API_HOST=192.168.1.100 -t lib/main_dev.dart
    if (_kApiHostOverride.isNotEmpty) {
      return 'http://$_kApiHostOverride:$port$apiPrefix';
    }

    // Desktop
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'http://localhost:$port$apiPrefix';
    }

    // Try to detect if running on emulator vs physical device
    if (Platform.isAndroid && await _isAndroidEmulator()) {
      return 'http://10.0.2.2:$port$apiPrefix';
    }

    if (Platform.isIOS) {
      // iOS Simulator often maps localhost directly
      final localhostPing = await _pingIp('127.0.0.1', port, apiPrefix);
      if (localhostPing != null) {
        return localhostPing;
      }
    }

    if (Platform.isAndroid) {
      // Check if adb reverse is active (localhost maps to PC)
      final adbReversePing = await _pingIp('127.0.0.1', port, apiPrefix);
      if (adbReversePing != null) {
        return 'http://127.0.0.1:$port$apiPrefix';
      }
    }

    // Subnet Scanning for physical devices / identical network fallback
    final scannedUrl = await scanForBackend(port: port, apiPrefix: apiPrefix);
    if (scannedUrl != null) {
      return scannedUrl;
    }

    // Fallback if scanning fails
    final host = await _resolveHost();
    return 'http://$host:$port$apiPrefix';
  }

  /// Tự động quét mạng LAN để tìm server Docker đang mở port
  static Future<String?> scanForBackend({
    int port = 8000,
    String apiPrefix = '/api/v1',
  }) async {
    // 1. Lấy IP của thiết bị (điện thoại thật)
    String? deviceIp = await _getLocalNetworkIp();
    if (deviceIp == 'localhost') return null;

    // 2. Cắt lấy Subnet (VD: "192.168.1.45" -> "192.168.1")
    final ipParts = deviceIp.split('.');
    if (ipParts.length != 4) return null;
    ipParts.removeLast();
    final subnet = ipParts.join('.');
    log(
      'Bắt đầu quét mạng LAN trên dải: $subnet.x:$port...',
      name: 'ApiUrlResolver',
    );

    // 3. Quét đồng thời, trả về ngay khi có IP đầu tiên phản hồi
    final completer = Completer<String?>();
    int pending = 253; // 254 - 1 (deviceIp)

    for (int i = 1; i <= 254; i++) {
      final targetIp = '$subnet.$i';
      if (targetIp == deviceIp) continue;

      _pingIp(targetIp, port, apiPrefix).then((url) {
        if (url != null && !completer.isCompleted) {
          completer.complete(url);
        } else {
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      });
    }

    // Nếu timeout tổng cộng 1.5s chưa xong thì trả về null luôn để tránh treo
    return await completer.future.timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () => null,
    );
  }

  /// Thử mở socket kết nối. Timeout ngắn (300ms) để quét lướt qua nhanh.
  static Future<String?> _pingIp(String ip, int port, String apiPrefix) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 1000),
      );
      socket.destroy(); // Kết nối thành công -> đóng lại ngay
      return 'http://$ip:$port$apiPrefix';
    } catch (_) {
      return null; // Kết nối thất bại (không có ai mở port ở IP này)
    }
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
      final isEmulator = await _isAndroidEmulator();
      if (isEmulator) {
        return '10.0.2.2';
      }
      return await _getLocalNetworkIp();
    }

    if (Platform.isIOS) {
      return 'localhost';
    }

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

  static String _apiUrlFromBase(String baseUrl, String apiPrefix) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.endsWith(apiPrefix)) {
      return normalized;
    }
    return '$normalized$apiPrefix';
  }
}
