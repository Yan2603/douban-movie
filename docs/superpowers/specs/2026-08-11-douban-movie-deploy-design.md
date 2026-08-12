# 豆瓣电影客户端 — 同机路径部署设计

日期：2026-08-11  
状态：已确认；实现计划见 `docs/superpowers/plans/2026-08-11-douban-movie-deploy.md`  
工程：`douban-movie`（Flutter Web）+ 既有 `interview` 同机共存

## 目标

在已部署 **interview** 的同一台服务器上，以同域名路径 **`/movie/`** 提供 douban Flutter Web，并具备与 interview 一致的 **GitHub Actions CI/CD**（SSH → 服务器 `git pull` + `docker compose up -d --build`）。

## 已锁定决策

| 主题 | 选择 |
|------|------|
| 访问方式 | 同域名路径 `/movie/`（非子域名、非独立端口） |
| 项目隔离 | douban 独立 Compose/容器；不把静态文件塞进 interview nginx 镜像 |
| 入口 | 前置 **edge Nginx** 独占宿主 `80`，按路径反代；**edge 归属 interview 仓库** `deploy/edge/` |
| interview 改动 | 去掉宿主 `"80:80"`，仅 `expose`，加入共享 Docker network；保留自有 nginx |
| 构建位置 | **服务器上 build**（对齐 interview；不用 GHCR 推拉） |
| CI/CD | GitHub Actions：test →（可选）compose build 校验 → SSH deploy |
| Deploy 脚本 | `git fetch` + `reset --hard origin/<branch>` + `docker compose up -d --build` |
| API Key | 服务器 `.env` / compose `build.args` → `--dart-define=TMDB_API_KEY`；不进 Git |
| base href | `flutter build web --base-href=/movie/` |
| 本期不做 | HTTPS/证书、GHCR、子域名、APK 分发、Flutter 业务改动 |

## 拓扑

```
浏览器  →  edge Nginx :80（宿主唯一 80）
              ├─ /movie/              → douban-web:80
              ├─ /movie-api/          → douban-api:3000（Nest；见 auth-favorites 设计）
              ├─ /api/、/uploads/、/  → interview-nginx:80
```

| 组件 | 职责 |
|------|------|
| edge | 路径分流；唯一映射宿主 `80:80`；配置与 compose 在 **interview** `deploy/edge/` |
| douban-web | 多阶段镜像：Flutter Web → nginx 静态；`expose: 80` |
| interview | 保留自有 nginx；不再 bind 宿主 80；加入 `edge-net`；详见 interview `docs/superpowers/specs/2026-08-11-edge-nginx-design.md` |

## douban Docker

### 多阶段 Dockerfile（概要）

1. **builder**：Flutter 官方/Cirrus 等镜像 → `flutter pub get` →  
   `flutter build web --release --base-href=/movie/ --dart-define=TMDB_API_KEY=$TMDB_API_KEY`
2. **runtime**：`nginx:alpine` → 拷贝 `build/web`；SPA `try_files $uri $uri/ /index.html`（需与 `/movie/` 前缀一致）

### Compose（概要）

- 服务 `web`：`build`（`args.TMDB_API_KEY` 来自 `.env`），`expose: ["80"]`，接入 `edge-net`
- `.env.example`：`TMDB_API_KEY=`
- `.env` gitignore（若尚未忽略则补上）

## edge Nginx（概要）

**不在本仓库维护。** 由 interview 仓库提供：

- `deploy/edge/nginx.conf`
- `deploy/edge/docker-compose.yml`（`container_name: edge-nginx`，`80:80`）

路由约定（实现见 interview 计划）：

```nginx
location /movie/ { proxy_pass http://douban-web:80; ... }   # 无 URI 后缀，保留完整路径
location /api/ { proxy_pass http://interview-nginx:80; ... }
location /uploads/ { proxy_pass http://interview-nginx:80; ... }
location / { proxy_pass http://interview-nginx:80; ... }
```

## interview 最小改动

由 interview 侧 `2026-08-11-edge-nginx` 设计/计划落地：

- nginx：`ports: ["80:80"]` → `expose: ["80"]`；`container_name: interview-nginx`
- 加入 external network `edge-net`
- 现有 CD 可继续，并在 deploy 时 `compose -f deploy/edge/... up -d`；首次切换入口有短暂停机窗口

## GitHub Actions（douban 仓库）

对齐 `interview/.github/workflows/ci.yml` 结构：

| Job | 触发 | 行为 |
|-----|------|------|
| test | PR + push | `flutter test`（可用 dummy `TMDB_API_KEY`） |
| docker | needs test | `docker compose build`（CI 内校验 Dockerfile；可用 dummy/secret key） |
| deploy | push/main（或 master）+ `workflow_dispatch` + `vars.DEPLOY_ENABLED == 'true'` | SSH：`cd DEPLOY_PATH` → `git fetch/reset` → `docker compose up -d --build` → 可选 `docker image prune` |

### Secrets / Vars

- Secrets：`DEPLOY_HOST`、`DEPLOY_USER`、`DEPLOY_SSH_KEY`、`DEPLOY_PORT`、`DEPLOY_PATH`
- Vars：`DEPLOY_ENABLED`
- 服务器：`DEPLOY_PATH` 下已有 clone + `.env`（含真实 `TMDB_API_KEY`）

## 一次性上线步骤

1. `docker network create edge-net || true`
2. 按 interview edge 计划：根 compose 去宿主 80 + 启动 `deploy/edge`
3. 服务器 clone douban 至 `DEPLOY_PATH`，配置 `.env`，`docker compose up -d --build`
4. 冒烟：`/` 与 `/movie/`
5. 配置 douban GitHub Deploy Secrets / `DEPLOY_ENABLED`

## 日常发布

- 合并到默认分支 → Actions 自动 SSH 部署 douban
- interview 与 douban **分仓库、分 workflow**，互不影响

## 回滚

- douban：服务器 `git reset --hard <旧 commit>` + `compose up -d --build`
- 入口切换失败：按 interview edge 计划回滚（停 `edge-nginx`，恢复 interview `"80:80"`）。

## 验收

- [ ] `/` → interview 正常（页面 + API）
- [ ] `/movie/` → Flutter 加载；热映有 TMDB 数据
- [ ] `/movie/` 下刷新/深链不 404
- [ ] 收藏读写正常（Web 持久化）
- [ ] douban Actions 可部署；失败不影响 interview

## 仓库改动面（实现时）

| 仓库 | 预期新增/修改 |
|------|----------------|
| douban-movie | `Dockerfile`、`docker-compose.yml`、`nginx.conf`、`.env.example`、`.github/workflows/ci.yml`、README（指向 interview edge） |
| interview | `deploy/edge/*`、`docker-compose.yml`（端口 + network）、README、CI deploy edge；见 `2026-08-11-edge-nginx` |
| 服务器（非 Git） | `edge-net`、douban clone + `.env` |

## 非目标

- 业务功能变更
- HTTPS / 证书自动化
- 镜像仓库（GHCR）推送部署
- 子域名或独立端口方案
