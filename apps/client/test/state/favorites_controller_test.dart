import 'dart:convert';

import 'package:douban_movie/auth/auth_controller.dart';
import 'package:douban_movie/auth/auth_repository.dart';
import 'package:douban_movie/auth/auth_store.dart';
import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/repositories/favorites_repository.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonUtf8Response(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

String _validAccessToken() {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode('{"sub":"u1","exp":9999999999}'),
  );
  return '$header.$payload.sig';
}

const sample = Movie(
  id: 550,
  title: 'Fight Club',
  posterPath: '/abc.jpg',
  voteAverage: 8.4,
  releaseDate: '1999-10-15',
);

class _FakeFavoritesRepository extends FavoritesRepository {
  _FakeFavoritesRepository();

  final List<Movie> remote = [];
  int fetchCalls = 0;
  int addCalls = 0;
  int removeCalls = 0;
  Object? addError;
  Object? removeError;
  Object? fetchError;

  @override
  Future<List<Movie>> fetchMine(String accessToken) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return List<Movie>.from(remote);
  }

  @override
  Future<Movie> add(String accessToken, Movie movie) async {
    addCalls++;
    if (addError != null) throw addError!;
    remote.removeWhere((m) => m.id == movie.id);
    remote.add(movie);
    return movie;
  }

  @override
  Future<void> remove(String accessToken, int tmdbId) async {
    removeCalls++;
    if (removeError != null) throw removeError!;
    remote.removeWhere((m) => m.id == tmdbId);
  }
}

class _UnauthThenSucceedRepository extends FavoritesRepository {
  _UnauthThenSucceedRepository(this._inner);

  final _FakeFavoritesRepository _inner;
  int addAttempts = 0;

  @override
  Future<List<Movie>> fetchMine(String accessToken) =>
      _inner.fetchMine(accessToken);

  @override
  Future<Movie> add(String accessToken, Movie movie) async {
    addAttempts++;
    if (addAttempts == 1) {
      throw FavoritesUnauthenticatedException();
    }
    return _inner.add(accessToken, movie);
  }

  @override
  Future<void> remove(String accessToken, int tmdbId) =>
      _inner.remove(accessToken, tmdbId);
}

Future<AuthController> _loggedInAuth({http.Client? client}) async {
  SharedPreferences.setMockInitialValues({
    AuthStore.accessTokenKey: _validAccessToken(),
    AuthStore.refreshTokenKey: 'refresh-abc',
  });
  final auth = AuthController(
    AuthRepository(
      client: client ??
          MockClient((_) async => jsonUtf8Response({}, 500)),
    ),
    AuthStore(),
  );
  await auth.restore();
  return auth;
}

/// Tracks whether [forceRefreshAccessToken] was used (vs soft ensureFresh).
class _TrackingAuthController extends AuthController {
  _TrackingAuthController(super.repo, super.store);

  int forceRefreshCalls = 0;

  @override
  Future<String?> forceRefreshAccessToken() async {
    forceRefreshCalls++;
    return super.forceRefreshAccessToken();
  }
}

Future<_TrackingAuthController> _loggedInTrackingAuth({
  required http.Client client,
}) async {
  SharedPreferences.setMockInitialValues({
    AuthStore.accessTokenKey: _validAccessToken(),
    AuthStore.refreshTokenKey: 'refresh-abc',
  });
  final auth = _TrackingAuthController(
    AuthRepository(client: client),
    AuthStore(),
  );
  await auth.restore();
  return auth;
}

Future<AuthController> _loggedOutAuth() async {
  SharedPreferences.setMockInitialValues({});
  final auth = AuthController(
    AuthRepository(
      client: MockClient((_) async => jsonUtf8Response({}, 500)),
    ),
    AuthStore(),
  );
  await auth.restore();
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesController', () {
    test('toggle when logged out returns false and skips API', () async {
      final auth = await _loggedOutAuth();
      final repo = _FakeFavoritesRepository();
      final controller = FavoritesController(auth, repo);

      final ok = await controller.toggle(sample);

      expect(ok, isFalse);
      expect(controller.isFavorite(550), isFalse);
      expect(repo.addCalls, 0);
      expect(repo.removeCalls, 0);
      expect(repo.fetchCalls, 0);
    });

    test('toggle when logged in adds via repository', () async {
      final auth = await _loggedInAuth();
      final repo = _FakeFavoritesRepository();
      final controller = FavoritesController(auth, repo);

      final ok = await controller.toggle(sample);

      expect(ok, isTrue);
      expect(controller.isFavorite(550), isTrue);
      expect(controller.items, [sample]);
      expect(repo.addCalls, 1);
      expect(repo.removeCalls, 0);
    });

    test('second toggle removes via repository', () async {
      final auth = await _loggedInAuth();
      final repo = _FakeFavoritesRepository()..remote.add(sample);
      final controller = FavoritesController(auth, repo);
      await controller.load();
      expect(controller.isFavorite(550), isTrue);

      final ok = await controller.toggle(sample);

      expect(ok, isTrue);
      expect(controller.isFavorite(550), isFalse);
      expect(repo.removeCalls, 1);
      expect(repo.addCalls, 0);
    });

    test('toggle rolls back when add fails', () async {
      final auth = await _loggedInAuth();
      final repo = _FakeFavoritesRepository()
        ..addError = FavoritesException('boom');
      final controller = FavoritesController(auth, repo);

      await expectLater(
        controller.toggle(sample),
        throwsA(isA<FavoritesException>()),
      );
      expect(controller.isFavorite(550), isFalse);
      expect(controller.items, isEmpty);
    });

    test('load clears when logged out', () async {
      final auth = await _loggedOutAuth();
      final repo = _FakeFavoritesRepository()..remote.add(sample);
      final controller = FavoritesController(auth, repo);

      await controller.load();

      expect(controller.items, isEmpty);
      expect(repo.fetchCalls, 0);
    });

    test('load fetches cloud favorites when logged in', () async {
      final auth = await _loggedInAuth();
      final repo = _FakeFavoritesRepository()..remote.add(sample);
      final controller = FavoritesController(auth, repo);

      await controller.load();

      expect(repo.fetchCalls, 1);
      expect(controller.items, [sample]);
    });

    test('UNAUTHENTICATED on add force-refreshes then succeeds', () async {
      var refreshCalls = 0;
      final newAccess = _validAccessToken();
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/refresh'));
        refreshCalls++;
        return jsonUtf8Response({
          'accessToken': newAccess,
          'refreshToken': 'refresh-new',
        }, 200);
      });
      final auth = await _loggedInTrackingAuth(client: client);
      final inner = _FakeFavoritesRepository();
      final repo = _UnauthThenSucceedRepository(inner);
      final controller = FavoritesController(auth, repo);

      final ok = await controller.toggle(sample);

      expect(ok, isTrue);
      expect(auth.forceRefreshCalls, 1);
      expect(refreshCalls, 1);
      expect(repo.addAttempts, 2);
      expect(inner.addCalls, 1);
      expect(controller.isFavorite(550), isTrue);
    });

    test('second UNAUTHENTICATED after force-refresh clears session', () async {
      var refreshCalls = 0;
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/refresh'));
        refreshCalls++;
        return jsonUtf8Response({
          'accessToken': _validAccessToken(),
          'refreshToken': 'refresh-new',
        }, 200);
      });
      final auth = await _loggedInTrackingAuth(client: client);
      final repo = _FakeFavoritesRepository()
        ..addError = FavoritesUnauthenticatedException();
      final controller = FavoritesController(auth, repo);

      await expectLater(
        controller.toggle(sample),
        throwsA(isA<FavoritesUnauthenticatedException>()),
      );

      expect(auth.forceRefreshCalls, 1);
      expect(refreshCalls, 1);
      expect(auth.isLoggedIn, isFalse);
      expect(controller.isFavorite(550), isFalse);
    });
  });
}
