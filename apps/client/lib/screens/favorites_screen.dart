import 'package:douban_movie/screens/movie_detail_screen.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:douban_movie/widgets/movie_poster_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final movies = favorites.items;

    if (movies.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => favorites.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('还没有收藏')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => favorites.load(),
      child: MoviePosterGrid(
        movies: movies,
        physics: const AlwaysScrollableScrollPhysics(),
        onTap: (movie) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MovieDetailScreen(
                movieId: movie.id,
                summary: movie,
              ),
            ),
          );
        },
      ),
    );
  }
}
