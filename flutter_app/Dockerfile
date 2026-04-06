FROM ghcr.io/cirruslabs/flutter:3.41.6 AS builder

WORKDIR /app
COPY pubspec.yaml ./
COPY pubspec.lock* ./
RUN flutter pub get

# v2 - force rebuild with dialect fix + TTS
COPY . .
RUN flutter build web --release

FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

# SPA routing — redirect all paths to index.html
RUN echo 'server { \
    listen 80; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
