import 'package:cached_network_image/cached_network_image.dart';
import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/widgets/favorite_button.dart';
import 'package:flutter/material.dart';

class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({
    super.key,
    required this.movie,
    this.onTap,
    this.showFavorite = true,
  });

  final Movie movie;
  final VoidCallback? onTap;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PosterImage(movie: movie),
                  if (showFavorite)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: FavoriteButton(movie: movie),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '评分 ${movie.voteAverage.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final url = movie.posterUrl;
    if (url == null) {
      return const ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Center(child: Icon(Icons.movie_outlined, color: Colors.grey)),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
      ),
    );
  }
}