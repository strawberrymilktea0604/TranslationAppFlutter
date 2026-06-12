class AppConfig {
  static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  final String appName;
  final String apiUrl;

  const AppConfig({required this.appName, required this.apiUrl});

  factory AppConfig.fromEnvironment({
    required String appName,
    String defaultBaseUrl = defaultApiBaseUrl,
  }) {
    final baseUrl = apiBaseUrl.isNotEmpty ? apiBaseUrl : defaultBaseUrl;

    return AppConfig(appName: appName, apiUrl: apiUrlFromBase(baseUrl));
  }

  static String apiUrlFromBase(String baseUrl) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

    if (normalized.endsWith('/api/v1')) {
      return normalized;
    }

    return '$normalized/api/v1';
  }
}
