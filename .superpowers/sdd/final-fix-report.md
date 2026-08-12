
## Final fix batch (2026-08-07 18:06)

### HTTP timeout (lib/repositories/movie_repository.dart)
- Added _get() wrapping _client.get(uri).timeout(_requestTimeout) (default 15s).
- TimeoutException maps to Exception('请求超时，请重试') for list/detail retry UI.
- Optional equestTimeout constructor param for fast unit tests.

### Repository tests
- Added equest timeout throws Exception with Chinese message using never-completing mock client and 50ms test timeout.

### Favorites save-failure rollback (	est/state/favorites_controller_test.dart)
- _ThrowingOnSaveFavoritesStore extends FavoritesStore overrides load/save; save throws.
- Tests cover add and remove toggle paths: expect rethrow, isFavorite and items rolled back.

### Verification
- lutter test: 15 passed, 0 failed.


## Whole-branch review fixes (2026-08-12)

### Changes
- CI: Postgres service + DATABASE_URL/JWT_*/TMDB_API_KEY; removed continue-on-error on server tests
- AuthService: JWT_ACCESS_TTL/JWT_REFRESH_TTL fall back to 15m/7d; JWT_ACCESS_SECRET still required
- LoginScreen: removed unused _formKey / Form wrapper
- AuthRepository: HTTP 400 -> 请求参数无效，请检查用户名和密码
- TYPEORM_SYNC policy unchanged (MVP debt)

### Commands + results
```
cd apps/server
# DATABASE_URL=postgres://douban:douban@localhost:5433/douban_movie (+ JWT_* + TMDB_API_KEY=dummy)
npm test
# → 3 suites, 15 passed

cd apps/client
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:9/api
# → 23 passed
```
