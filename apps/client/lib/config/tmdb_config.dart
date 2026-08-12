class TmdbConfig {
  static const String apiKey = String.fromEnvironment('TMDB_API_KEY');
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static bool get hasApiKey => apiKey.isNotEmpty;

  static String? posterUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) {
      return null;
    }
    return '$imageBaseUrl$posterPath';
  }
}