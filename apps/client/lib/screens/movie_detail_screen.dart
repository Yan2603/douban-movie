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
  bool _loading = true;
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
    final release = detail.releaseDate?.trim();
    final year = (release != null &&
            release.length >= 4 &&
            int.tryParse(release.substring(0, 4)) != null)
        ? release.substring(0, 4)
        : null;
    final titleText =
        year == null ? detail.title : '${detail.title} ($year)';
    final textTheme = Theme.of(context).textTheme;
    const labelColor = Color(0xFF666666);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titleText,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 135,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _DetailPoster(url: posterUrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: textTheme.bodyMedium?.copyWith(
                              height: 1.7,
                              color: labelColor,
                            ),
                            children: [
                              const TextSpan(text: '评分: '),
                              TextSpan(
                                text: detail.voteAverage.toStringAsFixed(1),
                                style: textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF494949),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (release != null && release.isNotEmpty)
                          Text(
                            '上映日期: $release',
                            style: textTheme.bodyMedium?.copyWith(
                              height: 1.7,
                              color: labelColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '剧情简介',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                overviewText,
                style: textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                  color: const Color(0xFF494949),
                ),
              ),
            ],
          ),
        ),
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
      width: double.infinity,
      height: double.infinity,
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