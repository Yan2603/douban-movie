import 'package:douban_movie/config/tmdb_config.dart';

class Movie {
  final int id;
  final String title;
  final String? posterPath;
  final double voteAverage;
  final String? releaseDate;

  const Movie({
    required this.id,
    required this.title,
    this.posterPath,
    required this.voteAverage,
    this.releaseDate,
  });

  String? get posterUrl => TmdbConfig.posterUrl(posterPath);

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String,
      posterPath: json['poster_path'] as String?,
      voteAverage: (json['vote_average'] as num).toDouble(),
      releaseDate: json['release_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster_path': posterPath,
      'vote_average': voteAverage,
      'release_date': releaseDate,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Movie &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            title == other.title &&
            posterPath == other.posterPath &&
            voteAverage == other.voteAverage &&
            releaseDate == other.releaseDate;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, posterPath, voteAverage, releaseDate);
}