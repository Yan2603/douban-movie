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
