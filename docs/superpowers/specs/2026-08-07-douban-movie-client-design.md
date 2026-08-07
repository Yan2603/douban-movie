# 豆瓣风格电影客户端（Flutter）— 设计说明

日期：2026-08-07  
状态：已确认，待写实现计划  
工程路径：`C:\Users\28939\douban-movie`（新项目；不改动 `flutter-demo`）

## 目标

用 Flutter 做一个豆瓣风格的电影客户端：

- 数据来自 **TMDB**（公开、有文档；豆瓣官方电影 API 已不可用）
- 提供 **正在热映列表** 与 **详情页**
- 用 **Provider** 管理收藏，并 **本地持久化**（杀进程再开仍在）

视觉偏豆瓣（绿色强调色、海报网格），不做像素级复刻。v1 不做登录、短评、影人页、搜索、多榜单 Tab。

## 已锁定决策

| 主题 | 选择 |
|------|------|
| 数据源 | TMDB（`/movie/now_playing`、`/movie/{id}`） |
| 与 Todo 练手项目关系 | 同级新工程；不动 `flutter-demo` |
| MVP 范围 | 列表 → 详情 → 收藏（含收藏 Tab） |
| 收藏 | Provider + SharedPreferences 持久化 |
| 架构 | 镜像 Todo 分层（models / repositories / state / screens / widgets） |
| 默认列表 | TMDB Now Playing（对应「正在热映」） |
| 语言 / 地区 | `language=zh-CN`；Now Playing 使用 `region=CN`（若接口支持） |
| 海报图 | TMDB CDN，例如 `https://image.tmdb.org/t/p/w500{poster_path}` |
| API Key | `--dart-define=TMDB_API_KEY=...`（密钥不进仓库） |

## 架构

```
lib/
  main.dart
  app.dart                 # MaterialApp + MultiProvider
  config/tmdb_config.dart  # baseUrl、图片 base、从环境读取 API key
  models/
    movie.dart             # 列表项摘要
    movie_detail.dart      # 详情字段
  repositories/
    movie_repository.dart  # TMDB HTTP（列表 + 详情）
  state/
    favorites_controller.dart
  storage/
    favorites_store.dart   # SharedPreferences
  screens/
    home_shell.dart        # 底部 Tab：热映 | 收藏
    movie_list_screen.dart
    movie_detail_screen.dart
    favorites_screen.dart
  widgets/
    movie_poster_card.dart
    favorite_button.dart
```

### 单元职责

| 单元 | 职责 | 依赖 |
|------|------|------|
| `MovieRepository` | 拉取热映 / 详情，解析 JSON | `http` + TMDB key |
| `FavoritesStore` | 读写本地收藏 JSON | `shared_preferences` |
| `FavoritesController` | 增删查收藏，通知 UI | `FavoritesStore` |
| Screens | 展示 UI，触发加载与导航 | Repository / Controller |

列表 / 详情的 `loading` / `data` / `error` 由 **页面本地状态** 管理（MVP 不做独立 ListController）。跨页共享状态只有收藏（Provider）。

## 数据流

### 列表

1. `MovieListScreen` 进入时（以及下拉刷新）调用 `MovieRepository.fetchNowPlaying()`。
2. 页面本地状态：`loading` / `movies` / `error`。
3. 点击卡片 → `Navigator.push` 进详情，传入 `movieId`（可选带摘要做占位）。

### 详情

1. 通过 `MovieRepository.fetchDetail(id)` 加载。
2. 展示海报、标题、评分、上映日、简介。
3. 收藏控件读写 `FavoritesController`。收藏时写入 **摘要**（`Movie`），收藏 Tab 无需再请求即可展示。

### 收藏

- 内存：`FavoritesController`（`ChangeNotifier`）内用 `Map<int, Movie>`（以 TMDB id 为键）。
- 磁盘：`FavoritesStore` 将条目序列化为 JSON，存入 SharedPreferences。
- 启动：先 `load` 再 hydrate Controller，然后再 `runApp`（或挡住首帧直到加载完成）。
- 列表卡、详情按钮、收藏 Tab 都监听同一 Controller，星标状态保持一致。

### 收藏 Tab

- 用同一套海报卡片渲染 Controller 中的条目。
- 空态文案：「还没有收藏」。
- 取消收藏立即从列表移除并写回 Store。

**成功标准：** 杀进程再开，收藏仍在；列表 / 详情 / 收藏三处星标一致。

## UI

- 主色：豆瓣绿约 `#00B51D`；浅灰背景、白卡片。
- 热映：双列海报网格；卡片含海报、标题、TMDB 评分。
- 详情：大海报（或 backdrop）+ 标题 + 评分 + 上映日 + 简介；AppBar / 工具栏收藏星标。
- 收藏 Tab：同款网格；空态文案。
- 底部导航：热映 | 收藏。
- 热映支持下拉刷新；图片用 `cached_network_image`，失败时灰色占位。

### v1 不做

登录、短评、影人页、搜索、Top / 即将上映等榜单 Tab、账号、分享。

## 错误处理

- 网络失败、超时、非 2xx：列表 / 详情展示错误文案 +「重试」。
- 未配置 API key：启动或首次请求时明确提示（禁止静默空列表）。
- 海报 URL 为空或加载失败：灰色占位。
- 收藏写盘失败：回滚内存变更或 SnackBar 提示，避免 UI 与磁盘不一致。
- 详情加载中：居中 Progress（或轻量骨架）；若已有摘要，可先允许操作收藏。

## 测试

- 单元：`FavoritesController` 的 toggle / 去重 / load-save（Store 可 mock）。
- Smoke：`Movie` / `MovieDetail` 用固定 fixture 做 JSON 解析。
- MVP 不做黄金截图与真机 E2E。

## 计划依赖

- `provider`
- `http`
- `shared_preferences`
- `cached_network_image`

## 运行说明（写入 README）

1. 在 https://www.themoviedb.org/ 申请 TMDB API key  
2. `flutter pub get`  
3. `flutter run --dart-define=TMDB_API_KEY=<key>`

## 非目标

- 替换或耦合 `flutter-demo` 的 Todo 代码  
- 使用非官方豆瓣爬虫 / 代理  
- 除收藏摘要外的完整离线片库缓存  
