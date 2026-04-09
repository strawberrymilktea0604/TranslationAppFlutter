import 'main.dart' as app;
import 'app_config.dart';

void main() {
  app.config = const AppConfig(
    appName: "TranslationApp",
    apiUrl: "https://api.com",
  );

  app.main();
}