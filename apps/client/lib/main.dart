import 'package:douban_movie/app.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:douban_movie/storage/favorites_store.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = FavoritesStore();
  final favorites = FavoritesController(store);
  await favorites.load();
  runApp(DoubanMovieApp(favoritesController: favorites));
}
