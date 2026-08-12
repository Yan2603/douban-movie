import 'dart:async';
import 'dart:convert';

import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/repositories/movie_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _testApiBaseUrl = 'http://127.0.0.1:9/api';

http.Response jsonUtf8Response(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('MovieRepository', () {
    test('fetchNowPlaying GETs Nest list endpoint and parses bare array',
        () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return jsonUtf8Response(
          [
            {
              'id': 1,
              'title': '热映片',
              'poster_path': '/p.jpg',
              'vote_average': 8.1,
              'release_date': '2024-01-01',
            },
          ],
          200,
        );
      });

      final repo = MovieRepository(
        client: client,
        apiBaseUrl: _testApiBaseUrl,
      );
      final movies = await repo.fetchNowPlaying();

      expect(captured, isNotNull);
      expect(
        captured!.url.toString(),
        '$_testApiBaseUrl/movies/now-playing',
      );
      expect(movies, [
        isA<Movie>()
            .having((m) => m.id, 'id', 1)
            .having((m) => m.title, 'title', '热映片'),
      ]);
    });

    test('fetchDetail GETs Nest movie detail by id', () async {
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

      final repo = MovieRepository(
        client: client,
        apiBaseUrl: _testApiBaseUrl,
      );
      final detail = await repo.fetchDetail(42);

      expect(captured!.url.toString(), '$_testApiBaseUrl/movies/42');
      expect(detail.id, 42);
      expect(detail.title, '详情片');
      expect(detail.overview, '简介文字');
    });

    test('non-2xx response throws Exception with status code', () async {
      final listClient = MockClient((_) async => http.Response('bad', 401));
      final listRepo = MovieRepository(
        client: listClient,
        apiBaseUrl: _testApiBaseUrl,
      );

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

      final detailClient =
          MockClient((_) async => http.Response('missing', 404));
      final detailRepo = MovieRepository(
        client: detailClient,
        apiBaseUrl: _testApiBaseUrl,
      );

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

    test('request timeout throws Exception with Chinese message', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      final repo = MovieRepository(
        client: client,
        apiBaseUrl: _testApiBaseUrl,
        requestTimeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        repo.fetchNowPlaying(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('请求超时，请重试'),
          ),
        ),
      );
    });
  });
}
