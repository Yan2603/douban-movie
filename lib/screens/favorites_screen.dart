import 'package:douban_movie/screens/movie_detail_screen.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:douban_movie/widgets/movie_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final movies = favorites.items;

    if (movies.isEmpty) {
      return const Center(child: Text('还没有收藏'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MoviePosterCard(
          movie: movie,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MovieDetailScreen(
                  movieId: movie.id,
                  summary: movie,
                ),
              ),
            );
          },
        );
      },
    );
  }
}