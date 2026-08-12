import 'package:douban_movie/app.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:douban_movie/storage/favorites_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('DoubanMovieApp shows home shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final favorites = FavoritesController(FavoritesStore());
    await favorites.load();

    await tester.pumpWidget(
      DoubanMovieApp(favoritesController: favorites),
    );
    await tester.pump();

    expect(
      find.textContaining('热映'),
      findsWidgets,
    );
  });
}
