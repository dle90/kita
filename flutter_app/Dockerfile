FROM ghcr.io/cirruslabs/flutter:3.41.6 AS builder

WORKDIR /app
COPY pubspec.yaml ./
COPY pubspec.lock* ./
RUN flutter pub get

# Copy all source — .build_id changes each deploy to bust Docker cache
COPY .build_id* ./
COPY . .
RUN flutter build web --release

FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

# Disable service worker caching and add SPA routing
RUN cat > /etc/nginx/conf.d/default.conf << 'NGINX'
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # Disable caching for service worker and main files
    location = /flutter_service_worker.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    location = /main.dart.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

EXPOSE 80
