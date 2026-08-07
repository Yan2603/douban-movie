import 'package:douban_movie/models/movie.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:douban_movie/storage/favorites_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sample = Movie(
    id: 550,
    title: 'Fight Club',
    posterPath: '/abc.jpg',
    voteAverage: 8.4,
    releaseDate: '1999-10-15',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoritesController', () {
    test('toggle add/remove persists across new controller load', () async {
      final store = FavoritesStore();
      final controller = FavoritesController(store);
      await controller.load();
      expect(controller.isFavorite(550), isFalse);

      await controller.toggle(sample);
      expect(controller.isFavorite(550), isTrue);
      expect(controller.items, [sample]);

      final controller2 = FavoritesController(store);
      await controller2.load();
      expect(controller2.isFavorite(550), isTrue);
      expect(controller2.items, [sample]);
    });

    test('second toggle same id removes', () async {
      final store = FavoritesStore();
      final controller = FavoritesController(store);
      await controller.load();

      await controller.toggle(sample);
      expect(controller.isFavorite(550), isTrue);

      await controller.toggle(sample);
      expect(controller.isFavorite(550), isFalse);
      expect(controller.items, isEmpty);

      final controller2 = FavoritesController(store);
      await controller2.load();
      expect(controller2.isFavorite(550), isFalse);
    });

    test('toggle rethrows and rolls back when save fails on add', () async {
      final store = _ThrowingOnSaveFavoritesStore();
      final controller = FavoritesController(store);
      await controller.load();
      expect(controller.isFavorite(550), isFalse);

      await expectLater(
        controller.toggle(sample),
        throwsA(isA<StateError>()),
      );
      expect(controller.isFavorite(550), isFalse);
      expect(controller.items, isEmpty);
    });

    test('toggle rethrows and rolls back when save fails on remove', () async {
      final store = _ThrowingOnSaveFavoritesStore(initial: [sample]);
      final controller = FavoritesController(store);
      await controller.load();
      expect(controller.isFavorite(550), isTrue);

      await expectLater(
        controller.toggle(sample),
        throwsA(isA<StateError>()),
      );
      expect(controller.isFavorite(550), isTrue);
      expect(controller.items, [sample]);
    });
  });
}

class _ThrowingOnSaveFavoritesStore extends FavoritesStore {
  _ThrowingOnSaveFavoritesStore({List<Movie> initial = const []})
      : _initial = List<Movie>.from(initial);

  final List<Movie> _initial;

  @override
  Future<List<Movie>> load() async => List<Movie>.from(_initial);

  @override
  Future<void> save(List<Movie> movies) async {
    throw StateError('Failed to persist favorites');
  }
}