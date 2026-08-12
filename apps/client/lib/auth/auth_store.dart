import 'package:shared_preferences/shared_preferences.dart';

class AuthStore {
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
  }

  Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(refreshTokenKey);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final okAccess = await prefs.setString(accessTokenKey, accessToken);
    final okRefresh = await prefs.setString(refreshTokenKey, refreshToken);
    if (!okAccess || !okRefresh) {
      throw StateError('Failed to persist auth tokens');
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
  }
}
