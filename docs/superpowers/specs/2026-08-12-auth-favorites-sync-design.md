# 登录、云收藏同步与 TMDB 后端代理 — 设计说明

日期：2026-08-12  
状态：已确认，待写实现计划  
工程路径：`C:\Users\28939\douban-movie`

## 目标

在现有 Flutter 豆瓣风电影客户端上增加：

1. **开放注册 / 登录 / 登出**（用户名 + 密码）
2. **按用户同步收藏**到自建后端
3. **TMDB 经 Nest 代理**，API Key 不再下发到客户端

未登录可浏览热映与详情；收藏需登录。

## 已锁定决策

| 主题 | 选择 |
|------|------|
| 产品形态 | 账号能力向：登录后按用户隔离收藏 |
| 注册 | 开放注册（登录页可切注册） |
| 未登录 | 可匿名看片；点收藏或进收藏 Tab 引导登录 |
| 仓库结构 | Monorepo：`apps/client`（Flutter）+ `apps/server`（NestJS） |
| API 切分 | REST 鉴权 + REST 电影代理；GraphQL 收藏 |
| 会话 | Access JWT（短）+ opaque refresh（长，落库哈希） |
| 数据库 | PostgreSQL + TypeORM |
| GraphQL 风格 | Nest code-first |
| 电影数据 | Nest REST 代理 TMDB；海报仍直连 TMDB CDN |
| 本地收藏 | 废弃未登录本地收藏；登录后只走服务端 |

## 架构

```
douban-movie/
├── apps/
│   ├── client/          # 现有 Flutter（从仓库根迁入）
│   └── server/          # NestJS + TypeORM + PostgreSQL
├── docker-compose.yml   # web + api + postgres
└── docs/superpowers/
```

### 职责划分

| 层 | 职责 |
|----|------|
| Flutter `apps/client` | UI；经自建 API 拉片与鉴权；GraphQL 收藏；token 本地持久化 |
| Nest `apps/server` | 用户/会话/收藏；TMDB 代理；不把 TMDB key 暴露给客户端 |
| PostgreSQL | `users` / `refresh_tokens` / `favorites` |

### API 面

| 类型 | 路径 | 鉴权 |
|------|------|------|
| REST | `POST /api/auth/register` | 公开 |
| REST | `POST /api/auth/login` | 公开 |
| REST | `POST /api/auth/refresh` | 公开（body 带 refresh） |
| REST | `POST /api/auth/logout` | 公开（body 带 refresh；吊销） |
| REST | `GET /api/movies/now-playing?page=` | 公开 |
| REST | `GET /api/movies/:tmdbId` | 公开 |
| GraphQL | `POST /api/graphql` | 收藏操作需 Bearer access |
| REST | `GET /api/health` | 公开 |

### 部署关系（与现有 edge 对齐）

- 静态 Web 仍挂 `/movie/`
- API 挂 `/movie-api/` 反代到 Nest（避免与 interview 的 `/api/` 冲突）；Nest 应用内仍使用全局前缀 `/api`
- Postgres 仅 compose 内网；生产不暴露宿主端口

### 服务端模块（逻辑边界）

| 单元 | 职责 | 依赖 |
|------|------|------|
| `AuthModule` | 注册/登录/刷新/登出；签发 access；管理 refresh | TypeORM User/RefreshToken；bcrypt；JWT |
| `MoviesModule` | 代理 TMDB now_playing / detail，映射为客户端 DTO | `TMDB_API_KEY`；HTTP 客户端 |
| `FavoritesModule` | GraphQL `myFavorites` / `addFavorite` / `removeFavorite` | JWT Guard；Favorite 实体 |
| `HealthModule` | 存活探针 | 可选查 DB |

### 客户端模块（逻辑边界）

| 单元 | 职责 | 依赖 |
|------|------|------|
| `AuthRepository` | register / login / refresh / logout | `http` + `API_BASE_URL` |
| `AuthController` | 登录态、token 持久化、单飞 refresh | `AuthRepository` + prefs |
| `AuthStore`（或 prefs 封装） | 读写 access/refresh | `shared_preferences` |
| `MovieRepository` | now-playing / detail（改打自建 REST） | `http` + `API_BASE_URL` |
| `FavoritesController` | 列表与 toggle；未登录引导登录 | GraphQL 客户端 + `AuthController` |
| `LoginScreen` | 登录/注册表单 | `AuthController` |

现有 `FavoritesStore`（本地 JSON `favorites_v1`）退役；不再作为未登录收藏后端。

## 数据模型

### users

- `id` UUID PK
- `username` 唯一、非空
- `password_hash`（bcrypt）
- `created_at`

### refresh_tokens

- `id` UUID PK
- `user_id` → users
- `token_hash`（只存哈希）
- `expires_at`
- `revoked_at` 可空
- `created_at`

### favorites

- `id` UUID PK
- `user_id` → users
- `tmdb_id` int
- `title` / `poster_path` / `vote_average` / `release_date`（列表摘要，对齐现有 `Movie`）
- `created_at`
- 唯一约束：`(user_id, tmdb_id)`

## 接口契约

### REST 鉴权

请求体：`{ "username": string, "password": string }`（register/login）  
成功响应：`{ "accessToken": string, "refreshToken": string }`  
Refresh：`{ "refreshToken": string }` → 新 token 对（refresh 轮换）  
Logout：`{ "refreshToken": string }` → 吊销该 refresh  

约定：

- Access：JWT，默认 TTL `15m`，payload `sub = userId`
- Refresh：opaque 随机串，默认 TTL `7d`，仅存哈希
- 密码最短长度 ≥ 6；用户名冲突 → `409`
- 登录失败（用户不存在或密码错）→ `401`，文案不区分具体原因（防枚举可接受简化）

### GraphQL 收藏

```graphql
type FavoriteMovie {
  tmdbId: Int!
  title: String!
  posterPath: String
  voteAverage: Float
  releaseDate: String
}

type Query {
  myFavorites: [FavoriteMovie!]!
}

type Mutation {
  addFavorite(input: AddFavoriteInput!): FavoriteMovie!
  removeFavorite(tmdbId: Int!): Boolean!
}

input AddFavoriteInput {
  tmdbId: Int!
  title: String!
  posterPath: String
  voteAverage: Float
  releaseDate: String
}
```

未带 / 无效 access → GraphQL `UNAUTHENTICATED`；前端引导重新登录（可先尝试 refresh）。

重复 `addFavorite`：幂等（已存在则返回已有记录）。

### REST 电影代理

| 方法 | 路径 | 上游 TMDB |
|------|------|-----------|
| GET | `/api/movies/now-playing?page=` | `/movie/now_playing`（`language=zh-CN`，`region=CN`） |
| GET | `/api/movies/:tmdbId` | `/movie/{id}` |

响应字段对齐现有 Flutter `Movie` / `MovieDetail`，减少 UI 改动。  
`TMDB_API_KEY` 仅存在于 server / compose 环境变量。  
客户端配置改为 `API_BASE_URL`（开发例：`http://localhost:3000/api`），移除 `--dart-define=TMDB_API_KEY`。

海报 URL 仍由客户端用 `poster_path` 拼 TMDB CDN（如 `https://image.tmdb.org/t/p/w500{path}`）。

## 数据流

### 注册 / 登录

1. 用户在登录页填写用户名、密码（可切换注册）
2. 客户端调用 register/login
3. 成功：持久化 access + refresh，返回原目标页（收藏 Tab 或详情）
4. 失败：表单内提示，不清无关状态

### 点收藏

1. 未登录：记下待收藏电影（可选 pending），跳转登录；成功后自动 `addFavorite`
2. 已登录：GraphQL add/remove；乐观更新 UI，失败回滚并提示

### 收藏 Tab

1. 未登录 → 登录页，成功后回到收藏 Tab
2. 已登录 → `myFavorites`；支持下拉刷新

### Access 过期

1. 业务请求收到 401 / `UNAUTHENTICATED`
2. 单飞调用 `/api/auth/refresh`
3. 成功：重试原请求
4. 失败：清 token，引导登录

### 登出

1. 调用 logout（失败也清本地 token）
2. 清空内存收藏列表

### 拉片

1. 列表/详情经 `MovieRepository` → Nest → TMDB
2. 页面本地 `loading` / `data` / `error` 模式保持不变

## 错误处理

| 场景 | 表现 |
|------|------|
| 网络失败 | 「网络异常，请稍后重试」 |
| 401 / refresh 失败 | 「登录已过期，请重新登录」 |
| 409 用户名占用 | 「用户名已被使用」 |
| 400 校验 | 字段或表单顶部提示 |
| 收藏重复 | 幂等成功 |
| TMDB 上游 5xx/超时 | Nest 返回 502；前端「加载失败，可重试」 |
| 无效电影 id | 404 |

服务端：全局异常过滤；密码与 refresh 明文不入日志。Auth 限流可作为增强项，MVP 可不做或只对 auth 做简单限流。

## 测试

### 服务端

- Auth：注册成功、重复用户名 409、登录成功/失败、refresh 轮换与吊销、logout 后 refresh 失效
- Favorites：未登录拒绝；增删查按 `user_id` 隔离；重复 add 幂等
- Movies：mock TMDB，校验 now-playing / detail 映射；缺少 `TMDB_API_KEY` 时启动或调用失败行为明确

### 客户端

- `AuthController`：登录态读写、refresh 失败清会话
- `FavoritesController`：未登录引导登录；登录后 toggle（mock GraphQL）
- `MovieRepository`：指向 mock API
- 冒烟：注册 → 登录 → 收藏 → 刷新仍在 → 登出后不可见；热映/详情经代理可加载

## 成功标准

1. 匿名可看热映/详情（经自建 REST，不经客户端 TMDB key）
2. 可注册、登录、登出
3. 登录后收藏按账号同步；同后端下换端同账号可见
4. Access 过期可自动 refresh；refresh 失效回到登录
5. 本地 `docker compose` 可起 `postgres + api + web`

## 明确不做（本期）

- 邮箱/验证码、第三方登录、改密找回
- 离线收藏队列、本地与云端合并策略
- 短评、搜索、影人页
- OAuth、复杂 RBAC
- Flutter secure storage（token 暂用 `shared_preferences`）
- 海报图反向代理
- now-playing 服务端缓存（可选增强，非必须）

## 配置清单（实现时）

| 变量 | 用途 |
|------|------|
| `DATABASE_URL` 或拆分 `POSTGRES_*` | Postgres 连接 |
| `JWT_ACCESS_SECRET` | Access 签名 |
| `JWT_ACCESS_TTL` | 默认 `15m` |
| `JWT_REFRESH_TTL` | 默认 `7d` |
| `TMDB_API_KEY` | 仅 server |
| `API_BASE_URL` | 仅 client（编译期或运行时配置） |
| `ALLOWED_ORIGINS` | CORS（含 Flutter web 源） |
