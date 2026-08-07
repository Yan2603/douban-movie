import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/models/movie_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MovieDetail', () {
    test('fromJson parses detail fields including overview and backdrop', () {
      final detail = MovieDetail.fromJson({
        'id': 550,
        'title': 'Fight Club',
        'poster_path': '/abc123.jpg',
        'backdrop_path': '/backdrop.jpg',
        'vote_average': 8.4,
        'release_date': '1999-10-15',
        'overview': 'An insomniac office worker...',
      });

      expect(detail.id, 550);
      expect(detail.title, 'Fight Club');
      expect(detail.posterPath, '/abc123.jpg');
      expect(detail.backdropPath, '/backdrop.jpg');
      expect(detail.voteAverage, 8.4);
      expect(detail.releaseDate, '1999-10-15');
      expect(detail.overview, 'An insomniac office worker...');
    });

    test('toMovie builds favorites summary with correct fields', () {
      final detail = MovieDetail.fromJson({
        'id': 99,
        'title': 'Summary Movie',
        'poster_path': '/p.jpg',
        'backdrop_path': '/bg.jpg',
        'vote_average': 7.2,
        'release_date': '2021-06-01',
        'overview': 'Long overview text not in Movie.',
      });

      final movie = detail.toMovie();

      expect(movie, isA<Movie>());
      expect(movie.id, 99);
      expect(movie.title, 'Summary Movie');
      expect(movie.posterPath, '/p.jpg');
      expect(movie.voteAverage, 7.2);
      expect(movie.releaseDate, '2021-06-01');
      expect(
        movie,
        const Movie(
          id: 99,
          title: 'Summary Movie',
          posterPath: '/p.jpg',
          voteAverage: 7.2,
          releaseDate: '2021-06-01',
        ),
      );
    });
  });
}
