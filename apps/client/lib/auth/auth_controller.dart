import 'dart:convert';

import 'package:douban_movie/auth/auth_repository.dart';
import 'package:douban_movie/auth/auth_store.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repo, this._store);

  final AuthRepository _repo;
  final AuthStore _store;

  String? _accessToken;
  String? _refreshToken;
  Future<String?>? _refreshInFlight;

  static const _skew = Duration(seconds: 60);

  bool get isLoggedIn =>
      _accessToken != null &&
      _accessToken!.isNotEmpty &&
      _refreshToken != null &&
      _refreshToken!.isNotEmpty;

  Future<void> restore() async {
    _accessToken = await _store.readAccessToken();
    _refreshToken = await _store.readRefreshToken();
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final tokens = await _repo.login(username, password);
    await _persist(tokens);
  }

  Future<void> register(String username, String password) async {
    final tokens = await _repo.register(username, password);
    await _persist(tokens);
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      await _repo.logout(refresh);
    }
    await _clearSession();
  }

  /// Returns access token; refreshes once if needed. Returns null if session dead.
  Future<String?> ensureFreshAccessToken() async {
    final access = _accessToken;
    if (access != null &&
        access.isNotEmpty &&
        !_isAccessExpiredOrNearExpiry(access)) {
      return access;
    }

    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) {
      await _clearSession();
      return null;
    }

    return _refreshInFlight ??= _doRefresh(refresh).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _doRefresh(String refresh) async {
    try {
      final tokens = await _repo.refresh(refresh);
      await _persist(tokens);
      return tokens.accessToken;
    } on AuthException {
      await _clearSession();
      return null;
    } catch (_) {
      await _clearSession();
      return null;
    }
  }

  Future<void> _persist(AuthTokens tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    await _store.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    await _store.clear();
    notifyListeners();
  }

  bool _isAccessExpiredOrNearExpiry(String token) {
    final exp = _readExp(token);
    if (exp == null) {
      // Unreadable token — force refresh path.
      return true;
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    return DateTime.now().toUtc().isAfter(expiresAt.subtract(_skew));
  }

  int? _readExp(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is int) return exp;
      if (exp is num) return exp.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }
}
