# douban_movie

豆瓣风格电影客户端（Flutter）。数据来自 [TMDB](https://www.themoviedb.org/) API。

## 环境要求

- Flutter SDK（与 pubspec.yaml 中 sdk 约束一致）
- 有效的 TMDB API Key（在 TMDB 账户设置中申请）

## TMDB API Key

本应用通过编译期常量传入 API Key，**请勿将密钥提交到 Git**。

在 [TMDB](https://www.themoviedb.org/settings/api) 获取 API Key 后，使用 --dart-define 运行或构建：

```bash
flutter run --dart-define=TMDB_API_KEY=你的密钥
```

其他示例：

```bash
flutter test --dart-define=TMDB_API_KEY=你的密钥
flutter build apk --dart-define=TMDB_API_KEY=你的密钥
```

## 开发

```bash
flutter pub get
flutter run --dart-define=TMDB_API_KEY=你的密钥
```

## 文档

设计与实现计划见 docs/superpowers/。

## 生产部署（与 interview 同机，路径 /movie/）

### 架构

- `edge-nginx`（容器）占用宿主 `:80`
- `/movie/` → `douban-web`
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
# 编辑 .env 填入真实 TMDB_API_KEY

# 4) 启动 douban（不占 80）
docker compose up -d --build

# 5) 冒烟
curl -sI http://127.0.0.1/ | head -n 1
curl -sI http://127.0.0.1/movie/ | head -n 1
```

### CI/CD

配置 GitHub Secrets：`DEPLOY_HOST`、`DEPLOY_USER`、`DEPLOY_SSH_KEY`、`DEPLOY_PORT`、`DEPLOY_PATH`；  
Repository variable `DEPLOY_ENABLED=true`。  
push 到 `main`/`master` 后会在服务器 `git reset --hard` + `docker compose up -d --build`。

### 回滚

```bash
cd "$DEPLOY_PATH"
git reset --hard <old-sha>
docker compose up -d --build
```

入口切换失败时：恢复 interview 的 `"80:80"`，`docker stop edge-nginx`。
