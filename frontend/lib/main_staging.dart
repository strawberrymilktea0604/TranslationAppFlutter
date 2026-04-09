import 'main.dart' as app;
import 'app_config.dart';

void main() {
  app.config = const AppConfig(
    appName: "TranslationAppStaging",
    apiUrl: "https://staging-api.com",
  );

  app.main();
}