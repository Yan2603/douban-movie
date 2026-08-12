import 'package:douban_movie/app.dart';
import 'package:douban_movie/auth/auth_controller.dart';
import 'package:douban_movie/auth/auth_repository.dart';
import 'package:douban_movie/auth/auth_store.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:douban_movie/storage/favorites_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('DoubanMovieApp shows home shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthController(
      AuthRepository(client: MockClient((_) async => http.Response('{}', 500))),
      AuthStore(),
    );
    await auth.restore();
    final favorites = FavoritesController(FavoritesStore());
    await favorites.load();

    await tester.pumpWidget(
      DoubanMovieApp(
        authController: auth,
        favoritesController: favorites,
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('热映'),
      findsWidgets,
    );
  });
}
