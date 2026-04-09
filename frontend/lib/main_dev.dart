import 'main.dart' as app;
import 'app_config.dart';

void main() {
  app.config = const AppConfig(
    appName: "TranslationAppDev",
    apiUrl: "https://dev-api.com",
  );

  app.main();
}