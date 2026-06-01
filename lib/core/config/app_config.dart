class AppConfig {
  AppConfig._();

  static const String _apiUrlFromEnv = String.fromEnvironment(
    'PLANORA_API_URL',
    defaultValue: 'https://planora-api-dqmv.onrender.com',
  );

  static String get apiBaseUrl {
    final trimmed = _apiUrlFromEnv.trim();

    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }

    return trimmed;
  }
}
