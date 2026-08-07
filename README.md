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