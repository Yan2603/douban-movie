import 'package:cached_network_image/cached_network_image.dart';
import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/models/movie_detail.dart';
import 'package:douban_movie/repositories/movie_repository.dart';
import 'package:douban_movie/widgets/favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movieId,
    this.summary,
  });

  final int movieId;
  final Movie? summary;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _loading = false;
  String? _error;
  MovieDetail? _detail;

  Movie? get _favoriteMovie => _detail?.toMovie() ?? widget.summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await context.read<MovieRepository>().fetchDetail(widget.movieId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is StateError ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _detail?.title ?? widget.summary?.title ?? '';
    final favoriteMovie = _favoriteMovie;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (favoriteMovie != null) FavoriteButton(movie: favoriteMovie),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    final overview = detail.overview?.trim();
    final overviewText =
        (overview == null || overview.isEmpty) ? '暂无简介' : overview;
    final posterUrl = detail.toMovie().posterUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _DetailPoster(url: posterUrl),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            detail.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '评分 ${detail.voteAverage.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (detail.releaseDate != null && detail.releaseDate!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '上映 ${detail.releaseDate}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            overviewText,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _DetailPoster extends StatelessWidget {
  const _DetailPoster({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Center(child: Icon(Icons.movie_outlined, color: Colors.grey)),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      ),
    );
  }
}