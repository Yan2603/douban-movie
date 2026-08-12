import 'package:douban_movie/auth/auth_controller.dart';
import 'package:douban_movie/repositories/movie_repository.dart';
import 'package:douban_movie/screens/home_shell.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DoubanMovieApp extends StatelessWidget {
  const DoubanMovieApp({
    super.key,
    required this.authController,
    required this.favoritesController,
  });

  final AuthController authController;
  final FavoritesController favoritesController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        Provider<MovieRepository>(create: (_) => MovieRepository()),
        ChangeNotifierProvider<FavoritesController>.value(
          value: favoritesController,
        ),
      ],
      child: MaterialApp(
        title: '豆瓣电影',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00B51D),
          ),
        ),
        home: const HomeShell(),
      ),
    );
  }
}
