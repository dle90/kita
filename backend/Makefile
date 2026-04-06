.PHONY: run build migrate-up migrate-down seed docker-up docker-down test

run:
	go run cmd/server/main.go

build:
	go build -o bin/server ./cmd/server

test:
	go test ./...

migrate-up:
	@echo "Running migrations up..."
	@for f in migrations/*.up.sql; do \
		echo "Applying $$f"; \
		PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -U $(DB_USER) -d $(DB_NAME) -f $$f; \
	done

migrate-down:
	@echo "Running migrations down..."
	@for f in $$(ls -r migrations/*.down.sql); do \
		echo "Reverting $$f"; \
		PGPASSWORD=$(DB_PASSWORD) psql -h $(DB_HOST) -U $(DB_USER) -d $(DB_NAME) -f $$f; \
	done

seed:
	@echo "Seeding is handled automatically on server start"
	@echo "Set SEED_DIR env var to override seed data location"

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

docker-build:
	docker-compose build

# Default DB connection params (override with env vars)
DB_HOST ?= localhost
DB_PORT ?= 5432
DB_USER ?= kita
DB_PASSWORD ?= kita_secret
DB_NAME ?= kita_english
