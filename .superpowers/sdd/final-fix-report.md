
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

