# cirruslabs/flutter stopped updating May 2026; community drop-in continues tags.
FROM ghcr.io/adrianjagielak/flutter:3.44.9 AS builder
WORKDIR /app

ARG API_BASE_URL=/movie-api/api

COPY apps/client/pubspec.yaml apps/client/pubspec.lock ./
COPY apps/client/ ./

RUN flutter config --enable-web \
 && flutter pub get \
 && flutter build web --release \
      --base-href=/movie/ \
      --dart-define=API_BASE_URL=${API_BASE_URL}

# daocloud mirror (same as interview) — avoid Docker Hub on CN servers
FROM docker.m.daocloud.io/library/nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/build/web /usr/share/nginx/html/movie
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
