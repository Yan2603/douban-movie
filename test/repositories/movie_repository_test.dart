import 'dart:convert';

import 'package:douban_movie/config/tmdb_config.dart';
import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/models/movie_detail.dart';
import 'package:douban_movie/repositories/movie_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _missingKeyMessage =
    '未配置 TMDB_API_KEY。请使用 flutter run --dart-define=TMDB_API_KEY=你的密钥';

http.Response jsonUtf8Response(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('MovieRepository', () {
    test('fetchNowPlaying requests zh-CN and CN region with api_key', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return jsonUtf8Response(
          {
            'results': [
              {
                'id': 1,
                'title': '热映片',
                'poster_path': '/p.jpg',
                'vote_average': 8.1,
                'release_date': '2024-01-01',
              },
            ],
          },
          200,
        );
      });

      final repo = MovieRepository(client: client, apiKey: 'test-key');
      final movies = await repo.fetchNowPlaying();

      expect(captured, isNotNull);
      expect(
        captured!.url.toString(),
        '${TmdbConfig.baseUrl}/movie/now_playing?api_key=test-key&language=zh-CN&region=CN',
      );
      expect(movies, [
        isA<Movie>()
            .having((m) => m.id, 'id', 1)
            .having((m) => m.title, 'title', '热映片'),
      ]);
    });

    test('fetchDetail requests movie id with zh-CN and api_key', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return jsonUtf8Response(
          {
            'id': 42,
            'title': '详情片',
            'poster_path': '/d.jpg',
            'backdrop_path': '/b.jpg',
            'vote_average': 7.2,
            'release_date': '2023-06-01',
            'overview': '简介文字',
          },
          200,
        );
      });

      final repo = MovieRepository(client: client, apiKey: 'secret');
      final detail = await repo.fetchDetail(42);

      expect(
        captured!.url.toString(),
        '${TmdbConfig.baseUrl}/movie/42?api_key=secret&language=zh-CN',
      );
      expect(detail.id, 42);
      expect(detail.title, '详情片');
      expect(detail.overview, '简介文字');
    });

    test('empty apiKey throws StateError with Chinese hint', () async {
      final repo = MovieRepository(
        client: MockClient((_) async => http.Response('{}', 200)),
        apiKey: '',
      );

      expect(
        () => repo.fetchNowPlaying(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            _missingKeyMessage,
          ),
        ),
      );
      expect(
        () => repo.fetchDetail(1),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            _missingKeyMessage,
          ),
        ),
      );
    });

    test('non-2xx response throws Exception with status code', () async {
      final listClient = MockClient((_) async => http.Response('bad', 401));
      final listRepo = MovieRepository(client: listClient, apiKey: 'k');

      expect(
        () => listRepo.fetchNowPlaying(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('401'),
          ),
        ),
      );

      final detailClient = MockClient((_) async => http.Response('missing', 404));
      final detailRepo = MovieRepository(client: detailClient, apiKey: 'k');

      expect(
        () => detailRepo.fetchDetail(9),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('404'),
          ),
        ),
      );
    });
  });
}