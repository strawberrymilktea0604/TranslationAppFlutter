import 'main.dart' as app;
import 'app_config.dart';

void main() {
  app.config = AppConfig.fromEnvironment(
    appName: "TranslationApp",
    defaultBaseUrl: "https://api.com",
  );

  app.main();
}
