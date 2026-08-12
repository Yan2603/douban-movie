# douban_movie

豆瓣风格电影客户端（Flutter）+ Nest 自建 API。影片数据经 Nest 代理 [TMDB](https://www.themoviedb.org/)，客户端不再携带 TMDB 密钥。

## 环境要求

- Flutter SDK（与 `apps/client/pubspec.yaml` 中 sdk 约束一致）
- Node.js 22+（本地跑 Nest）
- Docker（可选：Postgres / 全栈 compose）
- 服务端需配置 `TMDB_API_KEY`、`JWT_ACCESS_SECRET`（见根目录 `.env.example`）

## API 基址

Flutter 通过编译期常量 `API_BASE_URL` 访问自建 API：

| 场景 | 建议值 |
|------|--------|
| 本地 `flutter run` | `http://localhost:3000/api` |
| 生产 Web（edge） | `/movie-api/api`（Dockerfile 默认） |

```bash
cd apps/client
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

其他示例：

```bash
cd apps/client
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:9/api
flutter build apk --dart-define=API_BASE_URL=http://localhost:3000/api
```

## 本地联调（三终端）

```bash
# 0) 根目录 .env（从 .env.example 复制，填 TMDB_API_KEY / JWT_ACCESS_SECRET）
cp .env.example .env

# terminal 1 — Postgres（也可用本机 Postgres；DATABASE_URL 对齐 .env）
docker network create edge-net 2>/dev/null || true
docker compose up -d postgres
# 若需本机 Nest 连容器库，临时在 compose 给 postgres 加 ports: ["5432:5432"]

# terminal 2 — Nest API
cd apps/server
npm ci
npm run start:dev

# terminal 3 — Flutter
cd apps/client
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

也可 `docker compose up -d --build` 起 postgres + api + web；本地冒烟可给 `api` 临时映射 `3000:3000` 后：

```bash
curl -s http://localhost:3000/api/health
```

## 文档

设计与实现计划见 `docs/superpowers/`（鉴权/收藏：`specs/2026-08-12-auth-favorites-sync-design.md`）。

## 生产部署（与 interview 同机）

### 架构

- `edge-nginx`（interview `deploy/edge`）占用宿主 `:80`
- `/movie/` → `douban-web:80`（Flutter 静态）
- `/movie-api/` → `douban-api:3000`（Nest；见下方路径约定）
- `/`、`/api/`、`/uploads/` → `interview-nginx`

### edge `/movie-api/` 路径约定

客户端 `API_BASE_URL=/movie-api/api`，请求形如 `/movie-api/api/health`、`/movie-api/api/graphql`。  
edge 只剥掉前缀 `/movie-api`，保留后面的 `/api/...` 交给 Nest：

```nginx
location /movie-api/ {
    set $edge_target douban-api;
    set $douban_api_upstream douban-api:3000;
    rewrite ^/movie-api/(.*)$ /$1 break;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass http://$douban_api_upstream;
}
```

（实现在 interview 仓库 `deploy/edge/nginx.conf`。）

冒烟：`curl -sI http://127.0.0.1/movie-api/api/health` 应 200。

### 服务器一次性步骤

```bash
# 1) 网络
docker network create edge-net || true

# 2) interview 入口（edge 在 interview 仓库）
#    确保 deploy/edge/nginx.conf 含 /movie/ 与 /movie-api/
#    根 compose 去宿主 80 + deploy/edge up

# 3) clone 本仓库并配置密钥
git clone <repo-url> /opt/douban-movie   # DEPLOY_PATH 自定
cd /opt/douban-movie
cp .env.example .env
# 编辑 .env：TMDB_API_KEY、JWT_ACCESS_SECRET、GHCR_IMAGE 等
# API_BASE_URL 默认 /movie-api/api（Web 构建用）

# 4) 启动 douban（不占 80）：postgres + api + web
docker compose up -d --build
# 或 CI 推 GHCR 后：docker compose pull && docker compose up -d

# 5) 冒烟
curl -sI http://127.0.0.1/ | head -n 1
curl -sI http://127.0.0.1/movie/ | head -n 1
curl -s http://127.0.0.1/movie-api/api/health
```

### CI/CD

配置 GitHub Secrets：`DEPLOY_HOST`、`DEPLOY_USER`、`DEPLOY_SSH_KEY`、`DEPLOY_PORT`、`DEPLOY_PATH`；  
Repository variable `DEPLOY_ENABLED=true`。  
push 到 `main`/`master` 后会构建并推送 **web** + **api** 镜像，再在服务器 `git reset --hard` + `docker compose pull/up`。

镜像：`ghcr.io/<owner/repo>/web:<tag>`、`ghcr.io/<owner/repo>/api:<tag>`。

### 回滚

```bash
cd "$DEPLOY_PATH"
git reset --hard <old-sha>
export IMAGE_TAG=<old-sha>   # 若用 GHCR 标签
docker compose pull
docker compose up -d
```

入口切换失败时：恢复 interview 的 `"80:80"`，`docker stop edge-nginx`。
