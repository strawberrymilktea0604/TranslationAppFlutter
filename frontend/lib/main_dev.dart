import 'package:flutter/widgets.dart';

import 'package:frontend/core/utils/api_url_resolver.dart';

import 'main.dart' as app;
import 'app_config.dart';

void main() async {
  // Ensure Flutter binding is ready before async platform calls.
  WidgetsFlutterBinding.ensureInitialized();

  // Auto-detect the correct API URL based on the runtime environment:
  // - Android Emulator → http://10.0.2.2:8000/api/v1
  // - Physical Device  → http://<LAN_IP>:8000/api/v1
  // - iOS Simulator    → http://localhost:8000/api/v1
  // - Desktop          → http://localhost:8000/api/v1
  final apiUrl = await ApiUrlResolver.resolve(port: 8000);

  app.config = AppConfig(
    appName: "TranslationAppDev",
    apiUrl: apiUrl,
  );

  app.main();
}
