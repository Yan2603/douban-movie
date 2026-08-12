# douban_movie

豆瓣风格电影客户端（Flutter）+ Nest 自建 API。影片数据经 Nest 代理 [TMDB](https://www.themoviedb.org/)，客户端不再携带 TMDB 密钥。

## 环境要求

- Flutter SDK（与 `apps/client/pubspec.yaml` 中 sdk 约束一致）
- 本地开发：Nest API（默认 `http://localhost:3000/api`）与 Postgres；服务端需配置 `TMDB_API_KEY`

## API 基址

Flutter 通过编译期常量 `API_BASE_URL` 访问自建 API（默认开发值：`http://localhost:3000/api`）。生产 Web 构建默认为 `/movie-api/api`。

```bash
cd apps/client
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

其他示例：

```bash
cd apps/client
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:9/api
flutter build apk --dart-define=API_BASE_URL=http://localhost:3000/api
```

## 开发

Flutter 客户端位于 `apps/client/`：

```bash
cd apps/client
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

## 文档

设计与实现计划见 docs/superpowers/。

## 生产部署（与 interview 同机，路径 /movie/）

### 架构

- `edge-nginx`（容器）占用宿主 `:80`
- `/movie/` → `douban-web`（静态）
- `/movie-api/` → Nest API
- `/`、`/api/`、`/uploads/` → `interview-nginx`

### 服务器一次性步骤

```bash
# 1) 网络
docker network create edge-net || true

# 2) interview 入口（edge 在 interview 仓库）
#    按 interview docs/superpowers/plans/2026-08-11-edge-nginx.md：
#    根 compose 去宿主 80 + deploy/edge up

# 3) clone 本仓库并配置密钥
git clone <repo-url> /opt/douban-movie   # DEPLOY_PATH 自定
cd /opt/douban-movie
cp .env.example .env
# 编辑 .env：填入真实 TMDB_API_KEY（仅服务端）、JWT_ACCESS_SECRET 等
# API_BASE_URL 默认 /movie-api/api（客户端 Web 构建用）

# 4) 启动 douban（不占 80）
docker compose up -d --build

# 5) 冒烟
curl -sI http://127.0.0.1/ | head -n 1
curl -sI http://127.0.0.1/movie/ | head -n 1
```

### CI/CD

配置 GitHub Secrets：`DEPLOY_HOST`、`DEPLOY_USER`、`DEPLOY_SSH_KEY`、`DEPLOY_PORT`、`DEPLOY_PATH`；  
Repository variable `DEPLOY_ENABLED=true`。  
push 到 `main`/`master` 后会在服务器 `git reset --hard` + `docker compose pull/up`。

### 回滚

```bash
cd "$DEPLOY_PATH"
git reset --hard <old-sha>
docker compose up -d --build
```

入口切换失败时：恢复 interview 的 `"80:80"`，`docker stop edge-nginx`。
