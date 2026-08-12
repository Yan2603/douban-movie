import 'package:douban_movie/app.dart';
import 'package:douban_movie/auth/auth_controller.dart';
import 'package:douban_movie/auth/auth_repository.dart';
import 'package:douban_movie/auth/auth_store.dart';
import 'package:douban_movie/repositories/favorites_repository.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthController(AuthRepository(), AuthStore());
  await auth.restore();

  final favorites = FavoritesController(auth, FavoritesRepository());
  await favorites.load();

  runApp(
    DoubanMovieApp(
      authController: auth,
      favoritesController: favorites,
    ),
  );
}
