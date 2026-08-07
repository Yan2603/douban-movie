# Douban-Style Movie Client (Flutter) — Design

Date: 2026-08-07  
Status: Approved for planning  
Project path: `C:\Users\28939\douban-movie` (new app; does not modify `flutter-demo`)

## Goal

Build a Douban-inspired movie client in Flutter that:

- Fetches movies from **TMDB** (public, documented API; Douban’s official movie API is not usable)
- Shows a **Now Playing** list and a **detail** page
- Manages **favorites** with **Provider**, persisted locally across app restarts

Visual tone is Douban-like (green accent, poster grid), not a pixel-perfect clone. No login, reviews, cast pages, search, or multi-chart tabs in v1.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Data source | TMDB (`/movie/now_playing`, `/movie/{id}`) |
| Relationship to Todo demo | New sibling project; leave `flutter-demo` untouched |
| MVP scope | List → detail → favorites (with Favorites tab) |
| Favorites | Provider + SharedPreferences persistence |
| Architecture | Mirror Todo layering (models / repositories / state / screens / widgets) |
| Default list | TMDB Now Playing (“正在热映” analogue) |
| API language / region | `language=zh-CN`; Now Playing `region=CN` when supported |
| Poster images | TMDB image CDN, e.g. `https://image.tmdb.org/t/p/w500{poster_path}` |
| API key | `--dart-define=TMDB_API_KEY=...` (never commit secrets) |

## Architecture

```
lib/
  main.dart
  app.dart                 # MaterialApp + MultiProvider
  config/tmdb_config.dart  # baseUrl, image base, API key from environment
  models/
    movie.dart             # list-item summary
    movie_detail.dart      # detail fields
  repositories/
    movie_repository.dart  # TMDB HTTP (list + detail)
  state/
    favorites_controller.dart
  storage/
    favorites_store.dart   # SharedPreferences
  screens/
    home_shell.dart        # bottom tabs: Now Playing | Favorites
    movie_list_screen.dart
    movie_detail_screen.dart
    favorites_screen.dart
  widgets/
    movie_poster_card.dart
    favorite_button.dart
```

### Unit responsibilities

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `MovieRepository` | Fetch Now Playing / detail; parse JSON | `http` + TMDB key |
| `FavoritesStore` | Read/write favorites JSON | `shared_preferences` |
| `FavoritesController` | Add/remove/query favorites; notify UI | `FavoritesStore` |
| Screens | Render UI; trigger load & navigation | Repository / Controller |

List/detail loading state (`loading` / `data` / `error`) lives in the **screen** for MVP (no separate list controller). Favorites are the only cross-screen shared state via Provider.

## Data flow

### List

1. `MovieListScreen` calls `MovieRepository.fetchNowPlaying()` on enter (and on pull-to-refresh).
2. Local screen state: `loading` / `movies` / `error`.
3. Tap card → `Navigator.push` to detail with `movieId` (optional summary for placeholder).

### Detail

1. Load via `MovieRepository.fetchDetail(id)`.
2. Show poster, title, rating, release date, overview.
3. Favorite control reads/writes `FavoritesController`. On favorite, persist a **summary** (`Movie`) so the Favorites tab can render offline without re-fetching.

### Favorites

- In-memory: `Map<int, Movie>` (keyed by TMDB id) inside `FavoritesController` (`ChangeNotifier`).
- Disk: `FavoritesStore` serializes entries to JSON in SharedPreferences.
- Startup: load store → hydrate controller → then `runApp` (or block first frame until load completes).
- List cards, detail button, and Favorites tab all watch the same controller so star state stays consistent.

### Favorites tab

- Renders controller entries with the same poster card widget.
- Empty state: short copy (“还没有收藏”).
- Unfavorite removes immediately and writes store.

**Success criteria:** kill and relaunch app → favorites remain; star state matches across list, detail, and Favorites tab.

## UI

- Primary color: Douban green ≈ `#00B51D`; light gray background; white cards.
- Now Playing: two-column poster grid; card shows poster, title, TMDB vote average.
- Detail: large poster (or backdrop) + title + rating + release date + overview; favorite control in app bar / toolbar.
- Favorites tab: same grid; empty state copy.
- Bottom navigation: 热映 | 收藏.
- Pull-to-refresh on Now Playing; images via `cached_network_image` with gray placeholder on failure.

### Out of scope (v1)

Login, short reviews, person pages, search, Top Rated / Upcoming tabs, accounts, sharing.

## Error handling

- Network failure, timeout, non-2xx: show error message + Retry on list and detail.
- Missing API key: explicit message on startup or first request (never silent empty list).
- Missing/failed poster URL: gray placeholder.
- Favorites write failure: roll back in-memory change or show SnackBar so UI and disk do not diverge.
- Detail loading: centered progress (or light skeleton); if summary is already available, favorite control may be enabled before detail finishes.

## Testing

- Unit: `FavoritesController` toggle / dedupe / load-save with mocked store.
- Smoke: `Movie` / `MovieDetail` JSON parsing from fixed fixtures.
- No golden screenshots; no device E2E in MVP.

## Dependencies (planned)

- `provider`
- `http`
- `shared_preferences`
- `cached_network_image`

## Runbook (README will document)

1. Create a TMDB API key at https://www.themoviedb.org/
2. `flutter pub get`
3. `flutter run --dart-define=TMDB_API_KEY=<key>`

## Non-goals

- Replacing or coupling to `flutter-demo` Todo code
- Using unofficial Douban scrapers/proxies
- Production-grade offline movie cache beyond favorite summaries
