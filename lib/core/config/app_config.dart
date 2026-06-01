class AppConfig {
  AppConfig._();

  static const String _apiUrlFromEnv = String.fromEnvironment(
    'https://planora-api-dqmv.onrender.com/',
    defaultValue: 'https://127.0.0.1:8000',
  );

  static String get apiBaseUrl {
    final trimmed = _apiUrlFromEnv.trim();

    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }

    return trimmed;
  }
}
