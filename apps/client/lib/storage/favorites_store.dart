import 'dart:convert';

import 'package:douban_movie/models/movie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore {
  static const key = 'favorites_v1';

  Future<List<Movie>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Movie> movies) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(movies.map((m) => m.toJson()).toList());
    final ok = await prefs.setString(key, encoded);
    if (!ok) {
      throw StateError('Failed to persist favorites');
    }
  }
}