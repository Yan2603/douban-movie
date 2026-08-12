import 'dart:async';
import 'dart:convert';

import 'package:douban_movie/config/api_config.dart';
import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/models/movie_detail.dart';
import 'package:http/http.dart' as http;

class MovieRepository {
  MovieRepository({
    http.Client? client,
    String? apiBaseUrl,
    Duration? requestTimeout,
  })  : _client = client ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? ApiConfig.apiBaseUrl,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 15);

  final http.Client _client;
  final String _apiBaseUrl;
  final Duration _requestTimeout;

  Future<List<Movie>> fetchNowPlaying() async {
    final uri = Uri.parse('$_apiBaseUrl/movies/now-playing');
    final response = await _get(uri);
    _ensureSuccess(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MovieDetail> fetchDetail(int id) async {
    final uri = Uri.parse('$_apiBaseUrl/movies/$id');
    final response = await _get(uri);
    _ensureSuccess(response);
    return MovieDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri).timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception('请求超时，请重试');
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('请求失败，HTTP 状态码：${response.statusCode}');
    }
  }
}
