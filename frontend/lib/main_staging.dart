import 'main.dart' as app;
import 'app_config.dart';

void main() {
  app.config = AppConfig.fromEnvironment(
    appName: "TranslationAppStaging",
    defaultBaseUrl: "https://staging-api.com",
  );

  app.main();
}
