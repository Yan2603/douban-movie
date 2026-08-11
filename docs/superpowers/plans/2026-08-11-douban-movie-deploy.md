# Douban Movie Path Deploy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在已部署 interview 的同一台服务器上，用 Docker 容器 edge Nginx 把 `/movie/` 指到 douban Flutter Web，并加上与 interview 一致的 GitHub Actions CI/CD（SSH + 服务器 `git pull` + `compose up --build`）。

**Architecture:** edge 容器（**归属 interview** `deploy/edge/`）独占宿主 80，按路径反代到 `douban-web` 与 `interview-nginx`；douban 多阶段镜像（Flutter build web → nginx）；三方共用外部网络 `edge-net`；固定 `container_name` 做跨 compose DNS。

**Tech Stack:** Docker Compose、nginx:alpine、ghcr.io/cirruslabs/flutter、GitHub Actions、appleboy/ssh-action。

**Spec:** `docs/superpowers/specs/2026-08-11-douban-movie-deploy-design.md`

## Global Constraints

- 访问路径固定 `/movie/`；`flutter build web --base-href=/movie/`。
- 服务器上 build（对齐 interview）；不用 GHCR 推拉。
- `TMDB_API_KEY` 仅来自服务器/CI `.env` 或 secrets，禁止提交进 Git。
- edge 用 **容器** Nginx，配置在 **interview** `deploy/edge/`（本仓库不维护 edge）；不在宿主机 apt 安装 Nginx。
- 固定名：网络 `edge-net`；容器 `douban-web`、`interview-nginx`、`edge-nginx`。
- 本期不做 HTTPS、子域名、APK、Flutter 业务改动。
- commit 英文 conventional；douban 与 interview **分仓库提交**。
- interview 侧 edge / 去宿主 80：见 `interview/docs/superpowers/plans/2026-08-11-edge-nginx.md`。

## 文件映射

| 路径 | 仓库 | 职责 |
|------|------|------|
| `Dockerfile` | douban-movie | Flutter Web 多阶段构建 → nginx 静态 |
| `nginx.conf` | douban-movie | douban 容器内 SPA（`/movie/` 前缀） |
| `docker-compose.yml` | douban-movie | `web` 服务；接入 `edge-net` |
| `.env.example` | douban-movie | `TMDB_API_KEY=` 模板 |
| `.gitignore` | douban-movie | 忽略 `.env` |
| `.github/workflows/ci.yml` | douban-movie | test → docker build → SSH deploy |
| `README.md` | douban-movie | 本地/生产部署说明（edge 启动指向 interview） |
| `deploy/edge/*` | **interview** | 路径分流；占宿主 80（本计划不实现） |
| `docker-compose.yml` 等 | **interview** | nginx 去宿主 80；见 edge-nginx 计划 |

---

### Task 1: douban 镜像（Dockerfile + nginx + env）

**Files:**
- Create: `Dockerfile`
- Create: `nginx.conf`
- Create: `.env.example`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: 无
- Produces: 可本地 `docker build` 的镜像；运行时 HTTP 在容器内 `:80`，路径前缀 `/movie/`

- [ ] **Step 1: 把 `.env` 加入 `.gitignore`**

在 `.gitignore` 的 Superpowers 段落后追加：

```gitignore
# Local secrets (TMDB / deploy)
.env
```

- [ ] **Step 2: 创建 `.env.example`**

```env
TMDB_API_KEY=
```

- [ ] **Step 3: 创建 `nginx.conf`（douban 静态站）**

把构建产物放到镜像内 `/usr/share/nginx/html/movie/`，使 URL `/movie/...` 与 `--base-href=/movie/` 一致：

```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;
    gzip on;

    server {
        listen 80;
        server_name localhost;

        location /movie/ {
            root /usr/share/nginx/html;
            try_files $uri $uri/ /movie/index.html;
        }

        # 健康检查 / 误访问根路径时给出提示
        location = / {
            default_type text/plain;
            return 200 'douban-web: use /movie/\n';
        }
    }
}
```

- [ ] **Step 4: 创建 `Dockerfile`**

```dockerfile
# syntax=docker/dockerfile:1

FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app

ARG TMDB_API_KEY
RUN test -n "$TMDB_API_KEY" || (echo "TMDB_API_KEY build-arg is required" && exit 1)

COPY pubspec.yaml pubspec.lock ./
COPY . .

RUN flutter config --enable-web \
 && flutter pub get \
 && flutter build web --release \
      --base-href=/movie/ \
      --dart-define=TMDB_API_KEY=${TMDB_API_KEY}

FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/build/web /usr/share/nginx/html/movie
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

若 `pubspec.lock` 不存在，先在仓库根执行 `flutter pub get` 生成并提交后再构建。

- [ ] **Step 5: 本地校验构建（可用 dummy key）**

```bash
docker build --build-arg TMDB_API_KEY=dummy_ci_key -t douban-movie:local .
```

Expected: 构建成功，最后一层为 nginx。

冒烟（可选）：

```bash
docker run --rm -d --name douban-smoke -p 8088:80 douban-movie:local
curl -sI http://127.0.0.1:8088/movie/ | head -n 1
docker stop douban-smoke
```

Expected: `HTTP/1.1 200`（或 `200 OK`）。

- [ ] **Step 6: Commit（douban-movie）**

```bash
git add Dockerfile nginx.conf .env.example .gitignore
git commit -m "chore: add Flutter web Docker image for /movie/ path"
```

---

### Task 2: douban `docker-compose.yml`

**Files:**
- Create: `docker-compose.yml`

**Interfaces:**
- Consumes: Task 1 `Dockerfile`、`.env` 中的 `TMDB_API_KEY`
- Produces: 服务名 `web`；`container_name: douban-web`；网络 `edge-net`（external）

- [ ] **Step 1: 创建 `docker-compose.yml`**

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        TMDB_API_KEY: ${TMDB_API_KEY}
    container_name: douban-web
    restart: unless-stopped
    expose:
      - "80"
    networks:
      - edge-net

networks:
  edge-net:
    external: true
```

- [ ] **Step 2: 文档化网络前置条件（本机可测时）**

```bash
docker network create edge-net || true
echo TMDB_API_KEY=dummy_ci_key > .env
docker compose build
docker compose up -d
docker inspect -f '{{.Name}} {{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' douban-web
docker compose down
```

Expected: 容器名 `/douban-web`；已接入 `edge-net`。

- [ ] **Step 3: Commit（douban-movie）**

```bash
git add docker-compose.yml
git commit -m "chore: add compose service douban-web on edge-net"
```

---

### Task 3: edge + interview 入口（委托 interview 仓库）

**本仓库不实现。** 在 interview 按 `docs/superpowers/plans/2026-08-11-edge-nginx.md` 完成后再联调本仓库。

验收依赖（人工勾选）：

- [ ] interview 已提供 `deploy/edge/`，容器名 `edge-nginx` 占宿主 `:80`
- [ ] `interview-nginx` 仅 `expose: 80`，已接入 `edge-net`
- [ ] edge 将 `/movie/` 反代到 `douban-web:80`（无 URI 后缀）

---

### Task 4: （已合并进 Task 3 / interview 计划）

无本仓库步骤。原「interview compose 改动」全部在 interview `2026-08-11-edge-nginx` 计划中。

---

### Task 5: douban GitHub Actions CI/CD

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: 仓库根 `docker-compose.yml`；Secrets/Vars 与 interview 同名模式
- Produces: push `main`/`master` 且 `DEPLOY_ENABLED=true` 时 SSH 部署

- [ ] **Step 1: 创建 `.github/workflows/ci.yml`**

```yaml
name: deploy

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Pub get
        run: flutter pub get

      - name: Test
        run: flutter test --dart-define=TMDB_API_KEY=dummy_ci_key

  docker:
    name: Docker build
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - name: Create dummy env for compose
        run: echo 'TMDB_API_KEY=dummy_ci_key' > .env

      - name: Create edge-net for compose validation
        run: docker network create edge-net || true

      - name: Build image
        run: docker compose build

  deploy:
    name: Deploy to server
    needs: docker
    if: >-
      (github.event_name == 'push' || github.event_name == 'workflow_dispatch') &&
      (github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master') &&
      vars.DEPLOY_ENABLED == 'true'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.2.0
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          port: ${{ secrets.DEPLOY_PORT }}
          command_timeout: 60m
          script_stop: true
          script: |
            set -euo pipefail
            cd "${{ secrets.DEPLOY_PATH }}"
            git fetch origin
            git reset --hard "origin/${{ github.ref_name }}"
            docker compose up -d --build
            docker image prune -f
```

- [ ] **Step 2: Commit（douban-movie）**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add test, docker build, and SSH deploy workflow"
```

---

### Task 6: README 部署手册 + 规格勾选对齐

**Files:**
- Modify: `README.md`（douban-movie）
- Modify: `docs/superpowers/specs/2026-08-11-douban-movie-deploy-design.md`（状态改为「已出实现计划」）

**Interfaces:**
- Consumes: Tasks 1–5 的路径与容器名
- Produces: 服务器一次性上线可照抄的步骤

- [ ] **Step 1: 在 douban `README.md` 追加「生产部署」章节**

```markdown
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
```

- [ ] **Step 2: 更新规格文档状态行**

将 `状态：已确认，待写实现计划` 改为：

```markdown
状态：已确认；实现计划见 `docs/superpowers/plans/2026-08-11-douban-movie-deploy.md`
```

- [ ] **Step 3: Commit（douban-movie）**

```bash
git add README.md docs/superpowers/specs/2026-08-11-douban-movie-deploy-design.md
git commit -m "docs: add production deploy guide for /movie/ path"
```

---

### Task 7: 服务器联调验收（人工）

**Files:** 无代码；在目标服务器执行

**Interfaces:**
- Consumes: Tasks 1–6 全部产物；真实 `TMDB_API_KEY`
- Produces: 验收清单全部通过

- [ ] **Step 1: 按 README「服务器一次性步骤」完成切换**

顺序必须是：`edge-net` → interview（去宿主 80 + `deploy/edge` up）→ douban up → 冒烟。

- [ ] **Step 2: 验收**

| 检查 | 命令/操作 | Expected |
|------|-----------|----------|
| interview 首页 | 浏览器打开 `http://<host>/` | 面试驾驶舱正常 |
| interview API | 登录或 `GET /api/health` | 200 |
| douban 壳 | `http://<host>/movie/` | Flutter 加载 |
| TMDB 数据 | 热映列表 | 有海报/标题 |
| SPA 刷新 | 在详情页刷新 | 不 404 |
| 收藏 | 加收藏后刷新 | 仍在 |
| CD 隔离 | 仅触发 douban workflow | interview 容器无异常重启 |

- [ ] **Step 3: 配置 douban GitHub Secrets / `DEPLOY_ENABLED`，手动 `workflow_dispatch` 一次**

Expected: Actions 绿；服务器 `douban-web` 镜像更新时间刷新。

---

## 自检（对照规格）

| 规格项 | 任务 |
|--------|------|
| `/movie/` 路径 | Task 1 base-href + nginx |
| 独立 compose / 容器 | Task 2 |
| edge 容器占 80 | Task 3（interview `2026-08-11-edge-nginx`） |
| interview 去宿主 80 + edge-net | Task 3（同上） |
| 服务器 build + git pull CD | Task 5 |
| TMDB 不进 Git | Task 1 `.gitignore` / `.env.example` |
| 上线步骤 / 回滚 / 验收 | Task 6–7 |
| 不做 GHCR / HTTPS / 业务改动 | 全任务未引入 |

容器名锁定：`douban-web`、`interview-nginx`、`edge-nginx`；网络 `edge-net`。
edge 归属：**interview** `deploy/edge/`。
