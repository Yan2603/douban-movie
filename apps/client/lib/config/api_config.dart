class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static String? posterUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) return null;
    return '$imageBaseUrl$posterPath';
  }
}
