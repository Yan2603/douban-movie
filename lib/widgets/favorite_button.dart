import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.movie});

  final Movie movie;

  static const Color activeColor = Color(0xFF00B51D);

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final isFavorite = favorites.isFavorite(movie.id);

    return IconButton(
      icon: Icon(isFavorite ? Icons.star : Icons.star_border),
      color: isFavorite ? activeColor : null,
      tooltip: isFavorite ? '取消收藏' : '收藏',
      onPressed: () async {
        try {
          await favorites.toggle(movie);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('收藏保存失败，请重试')),
          );
        }
      },
    );
  }
}