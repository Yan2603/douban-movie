import 'dart:async';
import 'dart:convert';

import 'package:douban_movie/config/api_config.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}

class AuthRepository {
  AuthRepository({
    http.Client? client,
    String? apiBaseUrl,
    Duration? requestTimeout,
  })  : _client = client ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? ApiConfig.apiBaseUrl,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 15);

  final http.Client _client;
  final String _apiBaseUrl;
  final Duration _requestTimeout;

  Future<AuthTokens> register(String username, String password) {
    return _postCredentials('/auth/register', username, password);
  }

  Future<AuthTokens> login(String username, String password) {
    return _postCredentials('/auth/login', username, password);
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _postJson('/auth/refresh', {
      'refreshToken': refreshToken,
    });
    return _parseTokens(response, isLogin: false);
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _postJson('/auth/logout', {'refreshToken': refreshToken});
    } catch (_) {
      // best-effort
    }
  }

  Future<AuthTokens> _postCredentials(
    String path,
    String username,
    String password,
  ) async {
    final response = await _postJson(path, {
      'username': username,
      'password': password,
    });
    return _parseTokens(response, isLogin: path.endsWith('/login'));
  }

  Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_apiBaseUrl$path');
    try {
      return await _client
          .post(
            uri,
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw AuthException('网络异常，请稍后重试');
    } on http.ClientException {
      throw AuthException('网络异常，请稍后重试');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('网络异常，请稍后重试');
    }
  }

  AuthTokens _parseTokens(http.Response response, {required bool isLogin}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthTokens.fromJson(json);
    }

    if (response.statusCode == 409) {
      throw AuthException('用户名已被使用');
    }
    if (response.statusCode == 401 && isLogin) {
      throw AuthException('用户名或密码错误');
    }
    if (response.statusCode == 401) {
      throw AuthException('登录已失效，请重新登录');
    }
    throw AuthException('网络异常，请稍后重试');
  }
}
