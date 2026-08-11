import 'package:douban_movie/models/movie.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Movie', () {
    test('fromJson parses list item and posterUrl is full CDN URL', () {
      final movie = Movie.fromJson({
        'id': 550,
        'title': 'Fight Club',
        'poster_path': '/abc123.jpg',
        'vote_average': 8.4,
        'release_date': '1999-10-15',
      });

      expect(movie.id, 550);
      expect(movie.title, 'Fight Club');
      expect(movie.posterPath, '/abc123.jpg');
      expect(movie.voteAverage, 8.4);
      expect(movie.releaseDate, '1999-10-15');
      expect(
        movie.posterUrl,
        'https://image.tmdb.org/t/p/w500/abc123.jpg',
      );
    });

    test('toJson round-trip preserves equality', () {
      const original = Movie(
        id: 1,
        title: 'Test',
        posterPath: '/p.jpg',
        voteAverage: 7.5,
        releaseDate: '2020-01-01',
      );

      final restored = Movie.fromJson(original.toJson());
      expect(restored, original);
    });

    test('null poster_path yields null posterUrl', () {
      final movie = Movie.fromJson({
        'id': 2,
        'title': 'No Poster',
        'poster_path': null,
        'vote_average': 6.0,
        'release_date': null,
      });

      expect(movie.posterPath, isNull);
      expect(movie.posterUrl, isNull);
    });
  });
}