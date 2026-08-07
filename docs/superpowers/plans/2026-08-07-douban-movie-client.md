# 豆瓣风格电影客户端 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `C:\Users\28939\douban-movie` 新建 Flutter App：TMDB 热映列表 + 详情 + Provider 收藏（SharedPreferences），豆瓣风格。

**Architecture:** MovieRepository 拉 TMDB；FavoritesController + FavoritesStore 管收藏；Screen 本地管列表/详情 loading；HomeShell Tab（热映|收藏）。

**Tech Stack:** Flutter 3、provider、http、shared_preferences、cached_network_image。

**Spec:** `C:\Users\28939\douban-movie\docs\superpowers\specs\2026-08-07-douban-movie-client-design.md`

## Global Constraints

- 工程 `douban-movie`；禁止改 `flutter-demo`。
- TMDB；`language=zh-CN`；Now Playing `region=CN`。
- API Key：`--dart-define=TMDB_API_KEY=...`。
- 主色 `#00B51D`；空态「还没有收藏」。
- v1 不做登录/搜索/多榜单。
- 文案中文；commit 英文 conventional。
- 包名 `douban_movie`。

## 文件映射

| 路径 | 职责 |
|------|------|
| `lib/config/tmdb_config.dart` | API/图片配置 |
| `lib/models/movie.dart` | 列表摘要 |
| `lib/models/movie_detail.dart` | 详情 + toMovie |
| `lib/repositories/movie_repository.dart` | TMDB HTTP |
| `lib/storage/favorites_store.dart` | SharedPreferences |
| `lib/state/favorites_controller.dart` | 收藏状态 |
| `lib/widgets/*` | 海报卡、星标 |
| `lib/screens/*` | 列表/详情/收藏/壳 |
| `lib/app.dart` / `main.dart` | 注入与启动 |
| `test/**` | 单测 |

---

### Task 1: 脚手架

- [ ] 在 `C:\Users\28939\douban-movie`：`flutter create . --project-name douban_movie --org com.example`（保留 docs）
- [ ] 依赖：`provider`、`http`、`shared_preferences`、`cached_network_image`；`flutter pub get`
- [ ] README：TMDB key + `flutter run --dart-define=TMDB_API_KEY=...`
- [ ] Commit: `chore: scaffold Flutter movie app with dependencies`

### Task 2: Movie + TmdbConfig（TDD）

- [ ] `TmdbConfig`：`String.fromEnvironment('TMDB_API_KEY')`、baseUrl、imageBaseUrl、posterUrl
- [ ] 先写 `movie_test`（fromJson、round-trip、null poster）→ FAIL → 实现 `Movie` → PASS
- [ ] Commit: `feat: add Movie model and TmdbConfig`

### Task 3: MovieDetail（TDD）

- [ ] 测试 fromJson + `toMovie()` → 实现 → PASS
- [ ] Commit: `feat: add MovieDetail model`

### Task 4: MovieRepository

- [ ] `fetchNowPlaying()`：language=zh-CN，region=CN
- [ ] `fetchDetail(id)`；空 key 抛中文 StateError；可注入 http.Client
- [ ] MockClient 测试 → 实现 → PASS
- [ ] Commit: `feat: add MovieRepository for TMDB now playing and detail`

### Task 5: 收藏（TDD）

- [ ] Store key `favorites_v1`；`toggle` 切换语义；写盘失败回滚
- [ ] SharedPreferences mock 测试 → PASS
- [ ] Commit: `feat: add favorites store and controller with persistence`

### Task 6: Widgets

- [ ] `FavoriteButton`（SnackBar「收藏保存失败，请重试」；色 `#00B51D`）
- [ ] `MoviePosterCard`（CachedNetworkImage、评分）
- [ ] Commit: `feat: add poster card and favorite button widgets`

### Task 7: Screens

- [ ] `MovieListScreen`：loading/error/retry/RefreshIndicator/双列（aspect 0.58）
- [ ] `MovieDetailScreen(movieId, summary?)`：摘要可先收藏；「暂无简介」
- [ ] `FavoritesScreen`：空态「还没有收藏」
- [ ] `HomeShell`：IndexedStack + NavigationBar 热映|收藏
- [ ] Commit: `feat: add list, detail, favorites screens and home shell`

### Task 8: 串联

- [ ] `main`：`await favorites.load()` 后 runApp
- [ ] `DoubanMovieApp`：同一 FavoritesController；种子色 `#00B51D`
- [ ] `flutter test`；手工冒烟（杀进程收藏仍在；无 key 有提示）
- [ ] Commit: `feat: wire app providers, theme, and startup favorites load`

## 自检

新工程、TMDB、收藏、三页、豆瓣绿、错误处理、测试、README 均有 Task。无 TBD。
