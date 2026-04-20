import 'main.dart' as app;
import 'app_config.dart';

void main() {
  app.config = const AppConfig(
    appName: "TranslationAppDev",
    apiUrl: "http://10.0.2.2:8000/api/v1",
  );

  app.main();
}