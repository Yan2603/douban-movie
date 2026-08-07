import 'dart:convert';

import 'package:douban_movie/config/tmdb_config.dart';
import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/models/movie_detail.dart';
import 'package:http/http.dart' as http;

class MovieRepository {
  MovieRepository({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? TmdbConfig.apiKey;

  final http.Client _client;
  final String _apiKey;

  static const _missingKeyMessage =
      '未配置 TMDB_API_KEY。请使用 flutter run --dart-define=TMDB_API_KEY=你的密钥';

  Future<List<Movie>> fetchNowPlaying() async {
    _ensureApiKey();
    final uri = Uri.parse('${TmdbConfig.baseUrl}/movie/now_playing').replace(
      queryParameters: {
        'api_key': _apiKey,
        'language': 'zh-CN',
        'region': 'CN',
      },
    );
    final response = await _client.get(uri);
    _ensureSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>;
    return results
        .map((item) => Movie.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MovieDetail> fetchDetail(int id) async {
    _ensureApiKey();
    final uri = Uri.parse('${TmdbConfig.baseUrl}/movie/$id').replace(
      queryParameters: {
        'api_key': _apiKey,
        'language': 'zh-CN',
      },
    );
    final response = await _client.get(uri);
    _ensureSuccess(response);
    return MovieDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _ensureApiKey() {
    if (_apiKey.isEmpty) {
      throw StateError(_missingKeyMessage);
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('请求失败，HTTP 状态码：${response.statusCode}');
    }
  }
}