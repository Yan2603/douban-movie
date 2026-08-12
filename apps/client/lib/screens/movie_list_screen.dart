import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/repositories/movie_repository.dart';
import 'package:douban_movie/screens/movie_detail_screen.dart';
import 'package:douban_movie/widgets/movie_poster_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  bool _loading = true;
  String? _error;
  List<Movie> _movies = const [];

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
      final movies =
          await context.read<MovieRepository>().fetchNowPlaying();
      if (!mounted) return;
      setState(() {
        _movies = movies;
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
    if (_loading && _movies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _movies.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: _load,
      child: MoviePosterGrid(
        physics: const AlwaysScrollableScrollPhysics(),
        movies: _movies,
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