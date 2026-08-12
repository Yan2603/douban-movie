import 'dart:collection';

import 'package:douban_movie/auth/auth_controller.dart';
import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/repositories/favorites_repository.dart';
import 'package:flutter/foundation.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController(this._auth, this._repo);

  final AuthController _auth;
  final FavoritesRepository _repo;
  final LinkedHashMap<int, Movie> _byId = LinkedHashMap();

  List<Movie> get items => List.unmodifiable(_byId.values);

  bool isFavorite(int id) => _byId.containsKey(id);

  void clear() {
    _byId.clear();
    notifyListeners();
  }

  Future<void> load() async {
    if (!_auth.isLoggedIn) {
      _byId.clear();
      notifyListeners();
      return;
    }

    final token = await _auth.ensureFreshAccessToken();
    if (token == null) {
      _byId.clear();
      notifyListeners();
      return;
    }

    try {
      final movies = await _withAuthRetry(
        token,
        (access) => _repo.fetchMine(access),
      );
      _byId
        ..clear()
        ..addEntries(movies.map((m) => MapEntry(m.id, m)));
      notifyListeners();
    } on FavoritesUnauthenticatedException {
      _byId.clear();
      notifyListeners();
      rethrow;
    }
  }

  /// Returns `false` when not logged in (UI should push login).
  /// Returns `true` after a successful cloud add/remove.
  Future<bool> toggle(Movie movie) async {
    if (!_auth.isLoggedIn) return false;

    final snapshot = LinkedHashMap<int, Movie>.from(_byId);
    final removing = _byId.containsKey(movie.id);
    if (removing) {
      _byId.remove(movie.id);
    } else {
      _byId[movie.id] = movie;
    }
    notifyListeners();

    try {
      final token = await _auth.ensureFreshAccessToken();
      if (token == null) {
        throw FavoritesUnauthenticatedException();
      }
      await _withAuthRetry(token, (access) async {
        if (removing) {
          await _repo.remove(access, movie.id);
        } else {
          final saved = await _repo.add(access, movie);
          _byId[saved.id] = saved;
        }
      });
      notifyListeners();
      return true;
    } catch (e) {
      _byId
        ..clear()
        ..addAll(snapshot);
      notifyListeners();
      rethrow;
    }
  }

  Future<T> _withAuthRetry<T>(
    String initialToken,
    Future<T> Function(String accessToken) action,
  ) async {
    try {
      return await action(initialToken);
    } on FavoritesUnauthenticatedException {
      final refreshed = await _auth.ensureFreshAccessToken();
      if (refreshed == null) {
        rethrow;
      }
      return action(refreshed);
    }
  }
}
