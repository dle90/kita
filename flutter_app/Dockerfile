FROM ghcr.io/cirruslabs/flutter:3.41.6 AS builder

WORKDIR /app

# Copy everything at once — no layer caching for source files
COPY . .
RUN flutter pub get && flutter build web --release --pwa-strategy=none

FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

# Disable caching for all HTML/JS + SPA routing
RUN cat > /etc/nginx/conf.d/default.conf << 'NGINX'
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # No caching for app files
    add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    add_header Pragma "no-cache" always;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

EXPOSE 80
