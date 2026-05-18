import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:frontend/core/utils/api_url_resolver.dart';

import 'main.dart' as app;
import 'app_config.dart';

void main() async {
  // Ensure Flutter binding is ready before async platform calls.
  WidgetsFlutterBinding.ensureInitialized();

  // On Android physical device: run `adb reverse tcp:8000 tcp:8000`
  // so the device can reach the backend via localhost:8000 through USB.
  // Skipped on emulator (uses 10.0.2.2) and non-Android platforms.
  if (Platform.isAndroid) {
    try {
      await Process.run('adb', ['reverse', 'tcp:8000', 'tcp:8000']);
    } catch (_) {
      // ADB not available or not connected via USB — safe to ignore.
      // The LAN scan fallback in ApiUrlResolver will still find the server.
    }
  }

  // Auto-detect the correct API URL based on the runtime environment:
  // - Android Emulator → http://10.0.2.2:8000/api/v1
  // - Physical Device  → http://localhost:8000 (nếu adb reverse ok)
  //                      hoặc http://<LAN_IP>:8000/api/v1 (fallback)
  // - iOS Simulator    → http://localhost:8000/api/v1
  // - Desktop          → http://localhost:8000/api/v1
  final apiUrl = await ApiUrlResolver.resolve(port: 8000);

  app.config = AppConfig(
    appName: "TranslationAppDev",
    apiUrl: apiUrl,
  );

  app.main();
}
