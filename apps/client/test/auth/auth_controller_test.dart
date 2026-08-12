import 'dart:convert';

import 'package:douban_movie/auth/auth_controller.dart';
import 'package:douban_movie/auth/auth_repository.dart';
import 'package:douban_movie/auth/auth_store.dart';
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

/// JWT-like token with exp far in the future (year 2286).
String _validAccessToken() {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode('{"sub":"u1","exp":9999999999}'),
  );
  return '$header.$payload.sig';
}

/// JWT-like token that is already expired.
String _expiredAccessToken() {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(utf8.encode('{"sub":"u1","exp":1}'));
  return '$header.$payload.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthController', () {
    test('login success writes tokens to store and isLoggedIn', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/auth/login'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['username'], 'alice');
        expect(body['password'], 'secret1');
        return jsonUtf8Response({
          'accessToken': _validAccessToken(),
          'refreshToken': 'refresh-abc',
        }, 200);
      });

      final store = AuthStore();
      final repo = AuthRepository(client: client);
      final auth = AuthController(repo, store);

      await auth.login('alice', 'secret1');

      expect(auth.isLoggedIn, isTrue);
      expect(await store.readAccessToken(), _validAccessToken());
      expect(await store.readRefreshToken(), 'refresh-abc');
    });

    test('ensureFreshAccessToken clears session when refresh fails', () async {
      final expired = _expiredAccessToken();
      SharedPreferences.setMockInitialValues({
        AuthStore.accessTokenKey: expired,
        AuthStore.refreshTokenKey: 'stale-refresh',
      });

      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/refresh'));
        return jsonUtf8Response({'message': 'Unauthorized'}, 401);
      });

      final store = AuthStore();
      final repo = AuthRepository(client: client);
      final auth = AuthController(repo, store);
      await auth.restore();

      expect(auth.isLoggedIn, isTrue);

      final token = await auth.ensureFreshAccessToken();

      expect(token, isNull);
      expect(auth.isLoggedIn, isFalse);
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
    });

    test('ensureFreshAccessToken single-flight shares one refresh', () async {
      var refreshCalls = 0;
      final expired = _expiredAccessToken();
      SharedPreferences.setMockInitialValues({
        AuthStore.accessTokenKey: expired,
        AuthStore.refreshTokenKey: 'refresh-1',
      });

      final newAccess = _validAccessToken();
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/refresh'));
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return jsonUtf8Response({
          'accessToken': newAccess,
          'refreshToken': 'refresh-2',
        }, 200);
      });

      final store = AuthStore();
      final repo = AuthRepository(client: client);
      final auth = AuthController(repo, store);
      await auth.restore();

      final results = await Future.wait<String?>([
        auth.ensureFreshAccessToken(),
        auth.ensureFreshAccessToken(),
        auth.ensureFreshAccessToken(),
      ]);

      expect(refreshCalls, 1);
      expect(results, [newAccess, newAccess, newAccess]);
      expect(await store.readRefreshToken(), 'refresh-2');
    });
    test('ensureFreshAccessToken skips refresh when access still valid',
        () async {
      var refreshCalls = 0;
      SharedPreferences.setMockInitialValues({
        AuthStore.accessTokenKey: _validAccessToken(),
        AuthStore.refreshTokenKey: 'refresh-1',
      });

      final client = MockClient((request) async {
        refreshCalls++;
        return jsonUtf8Response({
          'accessToken': _validAccessToken(),
          'refreshToken': 'refresh-2',
        }, 200);
      });

      final store = AuthStore();
      final auth = AuthController(AuthRepository(client: client), store);
      await auth.restore();

      final token = await auth.ensureFreshAccessToken();

      expect(token, _validAccessToken());
      expect(refreshCalls, 0);
    });

    test('forceRefreshAccessToken always hits /auth/refresh when refresh exists',
        () async {
      var refreshCalls = 0;
      SharedPreferences.setMockInitialValues({
        AuthStore.accessTokenKey: _validAccessToken(),
        AuthStore.refreshTokenKey: 'refresh-1',
      });

      final newAccess = _validAccessToken();
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/refresh'));
        refreshCalls++;
        return jsonUtf8Response({
          'accessToken': newAccess,
          'refreshToken': 'refresh-2',
        }, 200);
      });

      final store = AuthStore();
      final auth = AuthController(AuthRepository(client: client), store);
      await auth.restore();

      // Access looks valid — ensureFresh would skip; force must still refresh.
      expect(await auth.ensureFreshAccessToken(), _validAccessToken());
      expect(refreshCalls, 0);

      final forced = await auth.forceRefreshAccessToken();

      expect(forced, newAccess);
      expect(refreshCalls, 1);
      expect(await store.readRefreshToken(), 'refresh-2');
    });
  });
}
