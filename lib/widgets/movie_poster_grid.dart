import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/widgets/movie_poster_card.dart';
import 'package:flutter/material.dart';

/// 按屏幕宽度自适应列数：单格最大约 180px，避免宽屏双列海报过大。
class MoviePosterGrid extends StatelessWidget {
  const MoviePosterGrid({
    super.key,
    required this.movies,
    required this.onTap,
    this.physics,
    this.padding = const EdgeInsets.all(8),
  });

  final List<Movie> movies;
  final void Function(Movie movie) onTap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  static const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 180,
    childAspectRatio: 0.58,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  );

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: physics,
      padding: padding,
      gridDelegate: gridDelegate,
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MoviePosterCard(
          movie: movie,
          onTap: () => onTap(movie),
        );
      },
    );
  }
}
