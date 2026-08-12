import 'dart:async';
import 'dart:convert';

import 'package:douban_movie/config/api_config.dart';
import 'package:douban_movie/models/movie.dart';
import 'package:http/http.dart' as http;

class FavoritesUnauthenticatedException implements Exception {
  @override
  String toString() => 'FavoritesUnauthenticatedException';
}

class FavoritesException implements Exception {
  FavoritesException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FavoritesRepository {
  FavoritesRepository({
    http.Client? client,
    String? apiBaseUrl,
    Duration? requestTimeout,
  })  : _client = client ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? ApiConfig.apiBaseUrl,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 15);

  final http.Client _client;
  final String _apiBaseUrl;
  final Duration _requestTimeout;

  static const _favoriteFields = '''
    tmdbId
    title
    posterPath
    voteAverage
    releaseDate
  ''';

  Future<List<Movie>> fetchMine(String accessToken) async {
    final data = await _postGraphql(
      accessToken: accessToken,
      query: '''
        query MyFavorites {
          myFavorites {
            $_favoriteFields
          }
        }
      ''',
    );
    final list = data['myFavorites'] as List<dynamic>? ?? const [];
    return list
        .map((e) => _movieFromFavorite(e as Map<String, dynamic>))
        .toList();
  }

  Future<Movie> add(String accessToken, Movie movie) async {
    final data = await _postGraphql(
      accessToken: accessToken,
      query: '''
        mutation AddFavorite(\$input: AddFavoriteInput!) {
          addFavorite(input: \$input) {
            $_favoriteFields
          }
        }
      ''',
      variables: {
        'input': {
          'tmdbId': movie.id,
          'title': movie.title,
          'posterPath': movie.posterPath,
          'voteAverage': movie.voteAverage,
          'releaseDate': movie.releaseDate,
        },
      },
    );
    return _movieFromFavorite(data['addFavorite'] as Map<String, dynamic>);
  }

  Future<void> remove(String accessToken, int tmdbId) async {
    await _postGraphql(
      accessToken: accessToken,
      query: '''
        mutation RemoveFavorite(\$tmdbId: Int!) {
          removeFavorite(tmdbId: \$tmdbId)
        }
      ''',
      variables: {'tmdbId': tmdbId},
    );
  }

  Future<Map<String, dynamic>> _postGraphql({
    required String accessToken,
    required String query,
    Map<String, dynamic>? variables,
  }) async {
    final uri = Uri.parse('$_apiBaseUrl/graphql');
    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'query': query,
              if (variables != null) 'variables': variables,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw FavoritesException('网络异常，请稍后重试');
    } on http.ClientException {
      throw FavoritesException('网络异常，请稍后重试');
    } catch (e) {
      if (e is FavoritesException || e is FavoritesUnauthenticatedException) {
        rethrow;
      }
      throw FavoritesException('网络异常，请稍后重试');
    }

    if (response.statusCode == 401) {
      throw FavoritesUnauthenticatedException();
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw FavoritesException('收藏服务响应异常');
    }

    final errors = body['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      if (_hasUnauthenticated(errors)) {
        throw FavoritesUnauthenticatedException();
      }
      final first = errors.first;
      final message = first is Map<String, dynamic>
          ? (first['message'] as String? ?? '收藏操作失败')
          : '收藏操作失败';
      throw FavoritesException(message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FavoritesException('收藏请求失败（${response.statusCode}）');
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw FavoritesException('收藏服务响应异常');
    }
    return data;
  }

  bool _hasUnauthenticated(List<dynamic> errors) {
    for (final error in errors) {
      if (error is! Map<String, dynamic>) continue;
      final extensions = error['extensions'];
      if (extensions is Map<String, dynamic>) {
        final code = extensions['code'];
        if (code == 'UNAUTHENTICATED') return true;
      }
      final message = error['message'] as String? ?? '';
      if (message.toUpperCase().contains('UNAUTHENTICATED')) return true;
    }
    return false;
  }

  Movie _movieFromFavorite(Map<String, dynamic> json) {
    return Movie(
      id: json['tmdbId'] as int,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      voteAverage: (json['voteAverage'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['releaseDate'] as String?,
    );
  }
}
