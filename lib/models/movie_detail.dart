import 'package:douban_movie/models/movie.dart';

class MovieDetail {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? releaseDate;
  final String? overview;

  const MovieDetail({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    this.releaseDate,
    this.overview,
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    return MovieDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num).toDouble(),
      releaseDate: json['release_date'] as String?,
      overview: json['overview'] as String?,
    );
  }

  Movie toMovie() {
    return Movie(
      id: id,
      title: title,
      posterPath: posterPath,
      voteAverage: voteAverage,
      releaseDate: releaseDate,
    );
  }
}
