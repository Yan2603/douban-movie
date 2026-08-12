# Auth, Cloud Favorites & TMDB Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 douban-movie 收成 `apps/client` + `apps/server` monorepo：Nest+Postgres 提供 REST 鉴权、TMDB 电影代理与 GraphQL 云收藏；Flutter 匿名可看片，登录后按用户同步收藏。

**Architecture:** Nest 全局前缀 `/api`；Auth/Movies 为 REST，Favorites 为 code-first GraphQL；access JWT + opaque refresh（哈希入库）；Flutter 用 `API_BASE_URL` 调自建 API，海报仍直连 TMDB CDN；生产经 edge 的 `/movie/`（静态）与 `/movie-api/`（API）分流。

**Tech Stack:** Flutter 3.44.x、Provider、http、graphql、shared_preferences；NestJS 11、TypeORM、PostgreSQL、@nestjs/graphql + Apollo、@nestjs/jwt、bcrypt、class-validator；Docker Compose。

**Spec:** `docs/superpowers/specs/2026-08-12-auth-favorites-sync-design.md`

## Global Constraints

- Monorepo：`apps/client`（Flutter）+ `apps/server`（Nest）；根目录保留 `docs/`、顶层 compose、CI。
- REST：`/api/auth/*`、`/api/movies/*`、`/api/health`；GraphQL：`POST /api/graphql`。
- Access JWT TTL 默认 `15m`；refresh TTL 默认 `7d`；密码 ≥ 6；用户名唯一冲突 `409`。
- `TMDB_API_KEY` 仅 server/compose；客户端禁止再使用 `--dart-define=TMDB_API_KEY`。
- 客户端配置：`API_BASE_URL`（开发默认 `http://localhost:3000/api`；生产 Web 构建用 `/movie-api/api`）。
- 未登录可看片；收藏需登录；废弃本地 `favorites_v1` JSON 收藏。
- 海报 CDN：`https://image.tmdb.org/t/p/w500`；不做海报反向代理。
- 生产 API 外网路径：`/movie-api/` → Nest（interview `deploy/edge` 需加 location）；Nest 内前缀仍为 `/api`。
- commit 英文 conventional；勿提交 `.env`、密钥。
- 本期不做：邮箱验证、第三方登录、离线合并、短评/搜索、secure storage、TMDB 缓存。

## 文件映射

| 路径 | 职责 |
|------|------|
| `apps/client/**` | 迁入后的 Flutter 应用（原根目录 `lib/`、`test/`、平台目录等） |
| `apps/server/src/main.ts` | Nest 启动、CORS、全局前缀 `api` |
| `apps/server/src/app.module.ts` | TypeORM + Auth/Movies/Favorites/Health |
| `apps/server/src/auth/**` | REST 鉴权、JWT、refresh |
| `apps/server/src/movies/**` | TMDB REST 代理 |
| `apps/server/src/favorites/**` | GraphQL 收藏 |
| `apps/server/src/health/**` | 健康检查 |
| `apps/client/lib/config/api_config.dart` | `API_BASE_URL` + 海报 CDN（替代 TMDB key 配置） |
| `apps/client/lib/auth/**` | AuthStore / AuthRepository / AuthController / LoginScreen |
| `apps/client/lib/repositories/movie_repository.dart` | 改打自建 movies API |
| `apps/client/lib/state/favorites_controller.dart` | 改走 GraphQL；登录门禁 |
| `docker-compose.yml` | `web` + `api` + `postgres` |
| `Dockerfile` / `Dockerfile.app` | Flutter Web；Nest API 镜像 |
| `.github/workflows/ci.yml` | client 测试路径 + 双镜像构建 |
| interview `deploy/edge/*` | 增加 `/movie-api/`（跨仓，本计划末任务文档化） |

---

### Task 1: Monorepo — 迁入 Flutter 到 `apps/client`

**Files:**
- Move: 根目录 Flutter 工程文件 → `apps/client/`（保留根 `docs/`、`.git`、已有 deploy 文档）
- Modify: `.github/workflows/ci.yml`（working-directory / 路径）
- Modify: `Dockerfile`（context 指向 `apps/client`）
- Modify: `README.md`（开发路径说明）

**Interfaces:**
- Consumes: 现有根目录 Flutter 布局
- Produces: `apps/client/pubspec.yaml` 可 `flutter test`；包名仍为 `douban_movie`

- [ ] **Step 1: 创建目录并迁移（在仓库根执行）**

PowerShell：

```powershell
New-Item -ItemType Directory -Force -Path apps | Out-Null
# 将 Flutter 应用迁入 apps/client（按实际根目录项调整列表）
$toMove = @(
  'lib','test','web','android','ios','linux','macos','windows',
  'pubspec.yaml','pubspec.lock','analysis_options.yaml',
  'douban_movie.iml','.metadata','.flutter-plugins-dependencies'
)
New-Item -ItemType Directory -Force -Path apps/client | Out-Null
foreach ($n in $toMove) {
  if (Test-Path $n) { git mv $n apps/client/ }
}
```

若 `git mv` 对部分生成文件失败，改用 `Move-Item` 后再 `git add`。  
**保留在根：** `docs/`、`Dockerfile`、`nginx.conf`、`docker-compose.yml`、`.github/`、`.env*`、`README.md`、`.gitignore`。

- [ ] **Step 2: 验证 client 仍可测试**

```powershell
cd apps/client
flutter pub get
flutter test --dart-define=TMDB_API_KEY=dummy_ci_key
```

Expected: 现有测试通过（本任务暂不改业务，仍可用旧 dart-define）。

- [ ] **Step 3: 更新 CI `test` job 使用 `apps/client`**

在 `.github/workflows/ci.yml` 的 test 步骤加 `working-directory: apps/client`（pub get / test）。

- [ ] **Step 4: 更新根 `Dockerfile` 的 COPY 路径**

将 `WORKDIR`/COPY 改为以 `apps/client` 为应用根，例如：

```dockerfile
FROM ghcr.io/adrianjagielak/flutter:3.44.9 AS builder
WORKDIR /app
ARG TMDB_API_KEY
RUN test -n "$TMDB_API_KEY" || (echo "TMDB_API_KEY build-arg is required" && exit 1)
COPY apps/client/pubspec.yaml apps/client/pubspec.lock ./
COPY apps/client/ ./
RUN flutter config --enable-web \
 && flutter pub get \
 && flutter build web --release \
      --base-href=/movie/ \
      --dart-define=TMDB_API_KEY=${TMDB_API_KEY}
```

（Task 8 起会把 `TMDB_API_KEY` 换成 `API_BASE_URL`；本任务先保持可构建。）

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: move Flutter app into apps/client monorepo layout"
```

---

### Task 2: Nest scaffold + Postgres + health

**Files:**
- Create: `apps/server/package.json`、`tsconfig.json`、`nest-cli.json`、`src/main.ts`、`src/app.module.ts`
- Create: `apps/server/src/health/health.controller.ts`、`health.module.ts`
- Create: `apps/server/.env.example`
- Modify: 根 `.gitignore`（忽略 `apps/server/dist`、`node_modules`）
- Modify: 根 `.env.example`（追加 DB/JWT 变量，TMDB 标为 server 用）

**Interfaces:**
- Consumes: 无
- Produces: `GET /api/health` → `{ "status": "ok" }`；TypeORM 可连 Postgres

- [ ] **Step 1: 用 Nest CLI 生成 server（或手写最小骨架）**

```powershell
cd apps
npx @nestjs/cli@11 new server --package-manager npm --skip-git
```

安装依赖：

```powershell
cd apps/server
npm i @nestjs/typeorm typeorm pg @nestjs/config class-validator class-transformer
npm i -D @types/node
```

- [ ] **Step 2: `main.ts` — 全局前缀与校验**

```typescript
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api');
  app.enableCors({
    origin: (process.env.ALLOWED_ORIGINS ?? 'http://localhost:5173,http://localhost:3000')
      .split(',')
      .map((s) => s.trim()),
    credentials: true,
  });
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
  );
  await app.listen(process.env.PORT ? Number(process.env.PORT) : 3000);
}
bootstrap();
```

- [ ] **Step 3: `AppModule` 接 Config + TypeORM**

```typescript
TypeOrmModule.forRootAsync({
  imports: [ConfigModule],
  inject: [ConfigService],
  useFactory: (config: ConfigService) => ({
    type: 'postgres',
    url: config.get<string>('DATABASE_URL'),
    autoLoadEntities: true,
    synchronize: config.get('TYPEORM_SYNC', 'true') === 'true', // 开发 true；生产计划后续改 migration
  }),
}),
```

`DATABASE_URL` 例：`postgres://douban:douban@localhost:5432/douban_movie`

- [ ] **Step 4: Health 模块**

```typescript
@Controller('health')
export class HealthController {
  @Get()
  check() {
    return { status: 'ok' };
  }
}
```

- [ ] **Step 5: 本地起 Postgres 并验证**

```powershell
docker run --name douban-pg -e POSTGRES_USER=douban -e POSTGRES_PASSWORD=douban -e POSTGRES_DB=douban_movie -p 5432:5432 -d postgres:16-alpine
cd apps/server
# 写 .env 后
npm run start:dev
curl http://localhost:3000/api/health
```

Expected: `{"status":"ok"}`

- [ ] **Step 6: Commit**

```bash
git add apps/server .gitignore .env.example
git commit -m "feat(server): scaffold Nest app with Postgres and health"
```

---

### Task 3: Auth — register / login（REST）

**Files:**
- Create: `apps/server/src/auth/entities/user.entity.ts`
- Create: `apps/server/src/auth/entities/refresh-token.entity.ts`
- Create: `apps/server/src/auth/dto/register.dto.ts`、`login.dto.ts`
- Create: `apps/server/src/auth/auth.service.ts`、`auth.controller.ts`、`auth.module.ts`
- Create: `apps/server/src/auth/auth.service.spec.ts`（或 e2e）
- Modify: `app.module.ts` 导入 `AuthModule`

**Interfaces:**
- Consumes: TypeORM、`JWT_ACCESS_SECRET`、`JWT_ACCESS_TTL`、`JWT_REFRESH_TTL`
- Produces:
  - `POST /api/auth/register` `{ username, password }` → `{ accessToken, refreshToken }`
  - `POST /api/auth/login` 同上
  - `User` entity: `id: string`, `username: string`, `passwordHash: string`

- [ ] **Step 1: 写失败测试（注册成功与重复用户名）**

用 Nest testing module + 内存或 testcontainers/Postgres；最小示例（service 级）：

```typescript
it('register returns token pair', async () => {
  const result = await service.register({ username: 'alice', password: 'secret1' });
  expect(result.accessToken).toBeDefined();
  expect(result.refreshToken).toBeDefined();
});

it('duplicate username throws ConflictException', async () => {
  await service.register({ username: 'alice', password: 'secret1' });
  await expect(
    service.register({ username: 'alice', password: 'secret1' }),
  ).rejects.toBeInstanceOf(ConflictException);
});
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
cd apps/server
npm test -- auth.service.spec.ts
```

Expected: FAIL（service 未实现）

- [ ] **Step 3: User / RefreshToken entities**

```typescript
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  username: string;

  @Column({ name: 'password_hash' })
  passwordHash: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

@Entity('refresh_tokens')
export class RefreshToken {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'token_hash' })
  tokenHash: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
  revokedAt: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
```

- [ ] **Step 4: AuthService.register / login**

要点：
- `bcrypt.hash(password, 10)` / `bcrypt.compare`
- DTO：`username` 非空；`password` `@MinLength(6)`
- access：`JwtService.sign({ sub: user.id })`
- refresh：`crypto.randomBytes(32).toString('hex')`，入库 `sha256` 哈希，`expiresAt = now + refreshTtl`
- 登录失败统一 `UnauthorizedException('用户名或密码错误')`
- 重复用户名 `ConflictException`

- [ ] **Step 5: AuthController 路由**

```typescript
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }
}
```

- [ ] **Step 6: 测试通过后 Commit**

```bash
git add apps/server/src/auth
git commit -m "feat(server): add register and login with JWT access tokens"
```

---

### Task 4: Auth — refresh / logout + JWT guard

**Files:**
- Modify: `auth.service.ts`、`auth.controller.ts`
- Create: `apps/server/src/auth/dto/refresh.dto.ts`
- Create: `apps/server/src/auth/guards/jwt-auth.guard.ts`
- Create: `apps/server/src/auth/strategies` 或手动 `AuthGuard` 解析 Bearer
- Create: `apps/server/src/auth/decorators/current-user.decorator.ts`

**Interfaces:**
- Consumes: RefreshToken entity
- Produces:
  - `POST /api/auth/refresh` `{ refreshToken }` → 新 `{ accessToken, refreshToken }`（旧 refresh 吊销）
  - `POST /api/auth/logout` `{ refreshToken }` → `{ ok: true }`
  - `JwtAuthGuard`：从 `Authorization: Bearer` 解析 `userId`
  - `@CurrentUser()` → `{ userId: string }`

- [ ] **Step 1: 测试 refresh 轮换与 logout 后失效**

```typescript
it('refresh rotates token and rejects old refresh', async () => {
  const first = await service.register({ username: 'bob', password: 'secret1' });
  const second = await service.refresh(first.refreshToken);
  await expect(service.refresh(first.refreshToken)).rejects.toBeInstanceOf(UnauthorizedException);
  expect(second.accessToken).toBeDefined();
});

it('logout revokes refresh', async () => {
  const tokens = await service.register({ username: 'carol', password: 'secret1' });
  await service.logout(tokens.refreshToken);
  await expect(service.refresh(tokens.refreshToken)).rejects.toBeInstanceOf(UnauthorizedException);
});
```

- [ ] **Step 2: 实现 refresh / logout**

- 查 `token_hash = sha256(raw)` 且 `revokedAt IS NULL` 且 `expiresAt > now`
- 轮换：吊销旧记录，签发新 access + 新 refresh
- logout：设 `revokedAt = now`（找不到也返回成功，避免泄露）

- [ ] **Step 3: JwtAuthGuard**

使用 `@nestjs/jwt` 校验 access；失败抛 `UnauthorizedException`。  
`@CurrentUser()` 读取 `request.user.userId`。

- [ ] **Step 4: 跑测试通过并 Commit**

```bash
git commit -m "feat(server): add refresh rotation, logout, and JWT guard"
```

---

### Task 5: Movies — TMDB REST 代理

**Files:**
- Create: `apps/server/src/movies/movies.service.ts`、`movies.controller.ts`、`movies.module.ts`
- Create: `apps/server/src/movies/movies.service.spec.ts`
- Modify: `app.module.ts`
- Modify: `apps/server/.env.example`（`TMDB_API_KEY=`）

**Interfaces:**
- Consumes: `TMDB_API_KEY`；上游 `https://api.themoviedb.org/3`
- Produces:
  - `GET /api/movies/now-playing?page=` → `{ results: MovieSummary[] }` 或直接 `MovieSummary[]`（**选定并固定为与 Flutter 现解析一致**）
  - `GET /api/movies/:tmdbId` → detail JSON

**响应字段（与现有 Flutter 模型对齐，snake_case）：**

列表项：`id`, `title`, `poster_path`, `vote_average`, `release_date`  
详情另加：`backdrop_path`, `overview`

- [ ] **Step 1: 写失败测试（mock fetch）**

```typescript
it('maps now_playing results', async () => {
  const http = { get: jest.fn().mockResolvedValue({ data: { results: [
    { id: 1, title: 'A', poster_path: '/x.jpg', vote_average: 8.1, release_date: '2024-01-01' },
  ]}})};
  const service = new MoviesService(http as any, configWithKey);
  const list = await service.nowPlaying(1);
  expect(list[0]).toEqual({
    id: 1, title: 'A', poster_path: '/x.jpg', vote_average: 8.1, release_date: '2024-01-01',
  });
});
```

- [ ] **Step 2: 实现 MoviesService**

- `nowPlaying(page)` → TMDB `/movie/now_playing?language=zh-CN&region=CN&page=`
- `detail(id)` → `/movie/{id}?language=zh-CN`
- 上游超时/5xx → `BadGatewayException`
- 上游 404 → `NotFoundException`
- 缺少 `TMDB_API_KEY` → 模块初始化或首次调用抛明确错误

推荐用 `@nestjs/axios` + `HttpService`，或原生 `fetch`。

- [ ] **Step 3: Controller**

```typescript
@Controller('movies')
export class MoviesController {
  constructor(private readonly movies: MoviesService) {}

  @Get('now-playing')
  nowPlaying(@Query('page') page = '1') {
    return this.movies.nowPlaying(Number(page) || 1);
  }

  @Get(':tmdbId')
  detail(@Param('tmdbId', ParseIntPipe) tmdbId: number) {
    return this.movies.detail(tmdbId);
  }
}
```

**契约固定：** `now-playing` 返回 **数组** `MovieSummary[]`（不是包一层 `results`），便于 Flutter `jsonDecode` 后直接 `List`。若返回包装对象，则 Task 8 必须同步解析——推荐数组。

- [ ] **Step 4: 手动冒烟**

```powershell
curl "http://localhost:3000/api/movies/now-playing"
curl "http://localhost:3000/api/movies/550"
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(server): proxy TMDB now-playing and movie detail"
```

---

### Task 6: Favorites — GraphQL

**Files:**
- Create: `apps/server/src/favorites/entities/favorite.entity.ts`
- Create: `apps/server/src/favorites/favorites.service.ts`
- Create: `apps/server/src/favorites/favorites.resolver.ts`
- Create: `apps/server/src/favorites/favorites.module.ts`
- Create: `apps/server/src/favorites/dto/add-favorite.input.ts`
- Create: `apps/server/src/favorites/models/favorite-movie.model.ts`
- Modify: `app.module.ts` — `GraphQLModule.forRoot`

**Interfaces:**
- Consumes: `JwtAuthGuard` / GraphQL auth context；`CurrentUser`
- Produces GraphQL（spec 一字不差）：
  - `Query.myFavorites: [FavoriteMovie!]!`
  - `Mutation.addFavorite(input): FavoriteMovie!`（幂等）
  - `Mutation.removeFavorite(tmdbId: Int!): Boolean!`

- [ ] **Step 1: 安装 GraphQL 依赖**

```powershell
cd apps/server
npm i @nestjs/graphql @nestjs/apollo @apollo/server graphql
```

- [ ] **Step 2: Favorite entity**

```typescript
@Entity('favorites')
@Unique(['userId', 'tmdbId'])
export class Favorite {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ name: 'tmdb_id', type: 'int' })
  tmdbId: number;

  @Column()
  title: string;

  @Column({ name: 'poster_path', type: 'varchar', nullable: true })
  posterPath: string | null;

  @Column({ name: 'vote_average', type: 'float', default: 0 })
  voteAverage: number;

  @Column({ name: 'release_date', type: 'varchar', nullable: true })
  releaseDate: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
```

- [ ] **Step 3: GraphQL module（code-first）**

```typescript
GraphQLModule.forRoot<ApolloDriverConfig>({
  driver: ApolloDriver,
  autoSchemaFile: true,
  path: '/api/graphql',
  context: ({ req }) => ({ req }),
}),
```

注意：若 `setGlobalPrefix('api')` 与 GraphQL `path` 叠加，确认最终 URL 为 **`POST /api/graphql`**（必要时设 `GraphQLModule` path 为 `/graphql` 并依赖全局前缀）。实现时用 curl 验证实际路径，以 spec 为准。

- [ ] **Step 4: Resolver + 鉴权**

对 Query/Mutation 使用 Guard；无 token → GraphQL 错误码 `UNAUTHENTICATED`。

```typescript
@Resolver(() => FavoriteMovie)
export class FavoritesResolver {
  constructor(private readonly favorites: FavoritesService) {}

  @Query(() => [FavoriteMovie])
  @UseGuards(GqlJwtAuthGuard)
  myFavorites(@CurrentUser() user: { userId: string }) {
    return this.favorites.listForUser(user.userId);
  }

  @Mutation(() => FavoriteMovie)
  @UseGuards(GqlJwtAuthGuard)
  addFavorite(
    @CurrentUser() user: { userId: string },
    @Args('input') input: AddFavoriteInput,
  ) {
    return this.favorites.add(user.userId, input);
  }

  @Mutation(() => Boolean)
  @UseGuards(GqlJwtAuthGuard)
  removeFavorite(
    @CurrentUser() user: { userId: string },
    @Args('tmdbId', { type: () => Int }) tmdbId: number,
  ) {
    return this.favorites.remove(user.userId, tmdbId);
  }
}
```

`FavoriteMovie` 字段名：`tmdbId`, `title`, `posterPath`, `voteAverage`, `releaseDate`（GraphQL camelCase）。

- [ ] **Step 5: 测试隔离与幂等**

```typescript
it('addFavorite is idempotent', async () => {
  const a = await service.add(userId, input);
  const b = await service.add(userId, input);
  expect(a.tmdbId).toBe(b.tmdbId);
  expect(await service.listForUser(userId)).toHaveLength(1);
});
```

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(server): add GraphQL favorites with JWT guard"
```

---

### Task 7: Flutter — Auth 层与登录页

**Files:**
- Create: `apps/client/lib/config/api_config.dart`
- Create: `apps/client/lib/auth/auth_store.dart`
- Create: `apps/client/lib/auth/auth_repository.dart`
- Create: `apps/client/lib/auth/auth_controller.dart`
- Create: `apps/client/lib/screens/login_screen.dart`
- Create: `apps/client/test/auth/auth_controller_test.dart`
- Modify: `apps/client/lib/app.dart`、`main.dart`
- Modify: `apps/client/pubspec.yaml`（若需）

**Interfaces:**
- Consumes: `POST $API_BASE_URL/auth/register|login|refresh|logout`
- Produces:
  - `AuthController.isLoggedIn`、`login`、`register`、`logout`、`ensureFreshAccessToken()`
  - `AuthStore` keys：`access_token`、`refresh_token`

- [ ] **Step 1: `ApiConfig`**

```dart
class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static String? posterUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) return null;
    return '$imageBaseUrl$posterPath';
  }
}
```

- [ ] **Step 2: AuthStore / AuthRepository / AuthController（含单飞 refresh）**

```dart
class AuthController extends ChangeNotifier {
  AuthController(this._repo, this._store);

  Future<void> restore() async { /* load tokens from store */ }

  Future<void> login(String username, String password) async { /* save tokens */ }

  Future<void> register(String username, String password) async { /* save tokens */ }

  Future<void> logout() async { /* call API best-effort; clear */ }

  /// Returns access token; refreshes once if needed. Returns null if session dead.
  Future<String?> ensureFreshAccessToken() async { /* single-flight */ }

  bool get isLoggedIn;
}
```

错误映射：409 → 「用户名已被使用」；401 登录 → 「用户名或密码错误」；网络 → 「网络异常，请稍后重试」。

- [ ] **Step 3: 单元测试 AuthController（mock http）**

覆盖：login 成功写 token；refresh 失败清会话。

- [ ] **Step 4: `LoginScreen`**

- 用户名、密码、登录/注册切换、提交 loading、错误文案
- `Navigator.pop(context, true)` 表示成功（调用方决定下一步）

- [ ] **Step 5: 接入 `main` / `MultiProvider`**

提供 `AuthController`；启动时 `await auth.restore()`。

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(client): add auth store, repository, controller, and login screen"
```

---

### Task 8: Flutter — MovieRepository 改打自建 API

**Files:**
- Modify: `apps/client/lib/repositories/movie_repository.dart`
- Modify: `apps/client/lib/models/movie.dart`（`posterUrl` 改用 `ApiConfig`）
- Delete or slim: `apps/client/lib/config/tmdb_config.dart`（迁移引用后删除）
- Modify: 相关 tests、`Dockerfile`、`.env.example`、`README.md`、CI

**Interfaces:**
- Consumes: `GET $API_BASE_URL/movies/now-playing`、`GET $API_BASE_URL/movies/:id`
- Produces: 现有 `List<Movie>` / `MovieDetail` API 不变

- [ ] **Step 1: 改写 MovieRepository**

```dart
class MovieRepository {
  MovieRepository({http.Client? client, String? apiBaseUrl, Duration? requestTimeout})
      : _client = client ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? ApiConfig.apiBaseUrl,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 15);

  Future<List<Movie>> fetchNowPlaying() async {
    final uri = Uri.parse('$_apiBaseUrl/movies/now-playing');
    final response = await _get(uri);
    _ensureSuccess(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => Movie.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MovieDetail> fetchDetail(int id) async {
    final uri = Uri.parse('$_apiBaseUrl/movies/$id');
    final response = await _get(uri);
    _ensureSuccess(response);
    return MovieDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
```

- [ ] **Step 2: 更新 / 删除 TmdbConfig 引用；修测试**

```powershell
cd apps/client
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:9/api
```

（无服务时仓库测试应 mock client；若现有测试打真网，改为注入 mock `http.Client`。）

- [ ] **Step 3: Dockerfile / CI 去掉 TMDB build-arg，改 API_BASE_URL**

```dockerfile
ARG API_BASE_URL=/movie-api/api
RUN flutter build web --release \
      --base-href=/movie/ \
      --dart-define=API_BASE_URL=${API_BASE_URL}
```

`.env.example`：

```env
TMDB_API_KEY=
DATABASE_URL=postgres://douban:douban@postgres:5432/douban_movie
JWT_ACCESS_SECRET=change-me
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=7d
API_BASE_URL=/movie-api/api
ALLOWED_ORIGINS=http://localhost:8080
```

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(client): fetch movies via Nest proxy instead of TMDB key"
```

---

### Task 9: Flutter — 云收藏 + 登录门禁

**Files:**
- Create: `apps/client/lib/repositories/favorites_repository.dart`（GraphQL）
- Modify: `apps/client/lib/state/favorites_controller.dart`
- Modify: `apps/client/lib/widgets/favorite_button.dart`
- Modify: `apps/client/lib/screens/favorites_screen.dart`、`home_shell.dart`
- Modify: `apps/client/lib/main.dart`（移除本地 FavoritesStore 启动加载）
- Delete: `apps/client/lib/storage/favorites_store.dart`（及依赖它的旧测试）
- Add: `graphql: ^5.2.0`（或当时 pub.dev 稳定版）到 `pubspec.yaml`
- Create: `apps/client/test/state/favorites_controller_test.dart`（重写）

**Interfaces:**
- Consumes: `AuthController.ensureFreshAccessToken()`；GraphQL `myFavorites` / `addFavorite` / `removeFavorite`
- Produces: `FavoritesController.load()`、`toggle(Movie)`、`items`、`isFavorite`；未登录时 `toggle`/进 Tab → push `LoginScreen`

- [ ] **Step 1: FavoritesRepository（http POST GraphQL）**

可用官方 `graphql` 包或手写：

```dart
Future<List<Movie>> fetchMine(String accessToken);
Future<Movie> add(String accessToken, Movie movie);
Future<void> remove(String accessToken, int tmdbId);
```

GraphQL 文档字符串与 spec 一致；把 `FavoriteMovie` 映射为 `Movie`（`id: tmdbId`）。

请求头：`Authorization: Bearer $accessToken`。  
若返回 UNAUTHENTICATED：抛专用异常，由 Controller 触发 refresh 重试一次。

- [ ] **Step 2: 重写 FavoritesController**

```dart
Future<void> load() async {
  if (!auth.isLoggedIn) {
    _byId.clear();
    notifyListeners();
    return;
  }
  final token = await auth.ensureFreshAccessToken();
  if (token == null) { /* clear; notify */ return; }
  final movies = await _repo.fetchMine(token);
  // replace map + notify
}

Future<bool> toggle(Movie movie) async {
  if (!auth.isLoggedIn) return false; // UI 负责跳登录
  // optimistic update + add/remove; rollback on error
  return true;
}
```

- [ ] **Step 3: UI 门禁**

- `FavoriteButton`：未登录 → `Navigator.push` LoginScreen；成功后 `toggle`
- `HomeShell` / `FavoritesScreen`：切到收藏 Tab 且未登录 → 登录页；成功后 `favorites.load()`
- AppBar 可加登出（可选但推荐）：调用 `auth.logout()` + `favorites.clear()`

登录成功后若有 pending `Movie`，自动 `addFavorite`。

- [ ] **Step 4: 测试**

- 未登录 `toggle` 返回 false / 不调 API
- 登录后 toggle 调 repository（mock）

```powershell
cd apps/client
flutter test
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(client): sync favorites via GraphQL with login gate"
```

---

### Task 10: Docker Compose + API 镜像 + edge 说明

**Files:**
- Create: `Dockerfile.app`（Nest 多阶段 build）
- Modify: `docker-compose.yml`（`postgres`、`api`、`web`）
- Modify: `README.md`
- Create or Modify: `docs/superpowers/specs` 旁的 deploy 笔记 / README 段落：interview edge 增加 `/movie-api/`
- Modify: `.github/workflows/ci.yml`（构建并推送 web + api 镜像；deploy compose）

**Interfaces:**
- Consumes: 根 `.env`（`TMDB_API_KEY`、`JWT_ACCESS_SECRET`、`DATABASE_URL` 等）
- Produces: `docker compose up` 起三服务；浏览器 `/movie/` 可用；API 经 `/movie-api/`（edge 配好后）

- [ ] **Step 1: `Dockerfile.app`**

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
COPY apps/server/package*.json ./
RUN npm ci
COPY apps/server/ ./
RUN npm run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY apps/server/package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

- [ ] **Step 2: `docker-compose.yml`**

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: douban
      POSTGRES_PASSWORD: douban
      POSTGRES_DB: douban_movie
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks: [edge-net]
    # 生产不映射宿主端口；本地开发可临时加 ports: ["5432:5432"]

  api:
    build:
      context: .
      dockerfile: Dockerfile.app
    environment:
      DATABASE_URL: postgres://douban:douban@postgres:5432/douban_movie
      JWT_ACCESS_SECRET: ${JWT_ACCESS_SECRET}
      JWT_ACCESS_TTL: ${JWT_ACCESS_TTL:-15m}
      JWT_REFRESH_TTL: ${JWT_REFRESH_TTL:-7d}
      TMDB_API_KEY: ${TMDB_API_KEY}
      ALLOWED_ORIGINS: ${ALLOWED_ORIGINS:-*}
      TYPEORM_SYNC: "true"
    depends_on: [postgres]
    expose: ["3000"]
    networks: [edge-net]
    container_name: douban-api

  web:
    image: ghcr.io/${GHCR_IMAGE}:${IMAGE_TAG:-latest}
    build:
      context: .
      dockerfile: Dockerfile
      args:
        API_BASE_URL: ${API_BASE_URL:-/movie-api/api}
    container_name: douban-web
    restart: unless-stopped
    expose: ["80"]
    networks: [edge-net]

networks:
  edge-net:
    external: true

volumes:
  pgdata:
```

- [ ] **Step 3: README — 本地联调**

```bash
# terminal 1: postgres + api（可用 compose profile 或只起 postgres）
# terminal 2:
cd apps/server && npm run start:dev
# terminal 3:
cd apps/client && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

- [ ] **Step 4: interview edge 配置（跨仓，文档化并尽量提交 interview）**

在 `edge-nginx` 配置增加：

```nginx
location /movie-api/ {
    proxy_pass http://douban-api:3000/api/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

注意 `proxy_pass` 尾部斜杠：外部 `/movie-api/graphql` → 内部 `/api/graphql`。用一次 curl 校准路径后再定稿。

- [ ] **Step 5: CI 更新**

- test：`working-directory: apps/client`，`--dart-define=API_BASE_URL=...`
- 可选：server `npm test`
- docker：build/push `Dockerfile`（web）与 `Dockerfile.app`（api）两个 tag 或同一 compose build on server

- [ ] **Step 6: 本地 compose 冒烟**

```powershell
docker network create edge-net
docker compose up -d --build
curl http://localhost:3000/api/health
# 若临时给 api 映射了 3000
```

Expected: health ok；注册/登录/收藏/热映全链路可在浏览器完成（edge 未改时可用直接映射 api 端口测）。

- [ ] **Step 7: Commit**

```bash
git commit -m "chore: add api image, postgres compose, and movie-api deploy notes"
```

- [ ] **Step 8: 更新 design spec 状态行**

将 `docs/superpowers/specs/2026-08-12-auth-favorites-sync-design.md` 状态改为：`已确认，实现计划见 docs/superpowers/plans/2026-08-12-auth-favorites-sync.md`。

```bash
git commit -m "docs: link auth favorites design to implementation plan"
```

---

## Spec coverage（自检）

| Spec 项 | Task |
|---------|------|
| Monorepo `apps/client` + `apps/server` | 1–2 |
| REST register/login/refresh/logout | 3–4 |
| Access + refresh 轮换/吊销 | 4 |
| TMDB REST 代理 + key 仅服务端 | 5, 8 |
| GraphQL 收藏 + 幂等 + 用户隔离 | 6 |
| 匿名看片、收藏门禁、登录页 | 7, 9 |
| 废弃本地 favorites_v1 | 9 |
| docker postgres+api+web、`/movie-api/` | 10 |
| 成功标准 1–5 | 贯穿 5–10 冒烟 |

## Placeholder / 一致性自检

- GraphQL 路径以实现后 curl 为准，目标固定 `POST /api/graphql`。
- `now-playing` 响应定为 **JSON 数组**（Task 5 与 Task 8 一致）。
- `Movie.id` ↔ GraphQL `tmdbId` 映射在 Task 9 写明。
- 无 TBD/TODO 步骤；跨仓 edge 变更在 Task 10 给出具体 nginx 片段。
