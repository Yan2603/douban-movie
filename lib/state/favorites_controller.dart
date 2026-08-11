import 'dart:collection';

import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/storage/favorites_store.dart';
import 'package:flutter/foundation.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController(this._store);

  final FavoritesStore _store;
  final LinkedHashMap<int, Movie> _byId = LinkedHashMap();

  List<Movie> get items => List.unmodifiable(_byId.values);

  Future<void> load() async {
    final movies = await _store.load();
    _byId.clear();
    for (final movie in movies) {
      _byId[movie.id] = movie;
    }
    notifyListeners();
  }

  bool isFavorite(int id) => _byId.containsKey(id);

  Future<void> toggle(Movie movie) async {
    final snapshot = LinkedHashMap<int, Movie>.from(_byId);
    if (_byId.containsKey(movie.id)) {
      _byId.remove(movie.id);
    } else {
      _byId[movie.id] = movie;
    }
    notifyListeners();
    try {
      await _store.save(items);
    } catch (e) {
      _byId
        ..clear()
        ..addAll(snapshot);
      notifyListeners();
      rethrow;
    }
  }
}