# =============================================================================
# NutriMind — Makefile for OrbStack / Docker Compose
# =============================================================================
# Usage:
#   make help            — list available commands
#   make up              — start core stack (postgres, redis, backend, frontend, mailhog)
#   make up-telegram     — core + telegram bot
#   make up-elk          — core + Elastic observability stack (es, kibana, logstash, beats, apm)
#   make up-full         — everything (use sparingly; ELK uses ~1.5 GB RAM)
#   make down            — stop everything
#   make logs            — tail logs for all running services
# =============================================================================

SHELL := /bin/bash
COMPOSE := docker compose

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

.PHONY: up
up: ## Start core stack in the background (postgres, redis, backend, frontend, mailhog)
	$(COMPOSE) up -d --build
	@echo ""
	@echo "Core stack is up. Open:"
	@echo "  Frontend:  http://localhost:3000"
	@echo "  API docs:  http://localhost:8000/api/docs"
	@echo "  MailHog:   http://localhost:8025"

.PHONY: down
down: ## Stop the entire stack (keeps volumes and images)
	$(COMPOSE) --profile "*" down

.PHONY: stop
stop: ## Stop running containers without removing them
	$(COMPOSE) --profile "*" stop

.PHONY: restart
restart: ## Restart all running services
	$(COMPOSE) --profile "*" restart

.PHONY: ps
ps: ## Show running services (all profiles)
	$(COMPOSE) --profile "*" ps

.PHONY: logs
logs: ## Tail logs for every running service
	$(COMPOSE) --profile "*" logs -f --tail=100

.PHONY: logs-backend
logs-backend: ## Tail backend logs only
	$(COMPOSE) logs -f --tail=100 backend

.PHONY: logs-frontend
logs-frontend: ## Tail frontend logs only
	$(COMPOSE) logs -f --tail=100 frontend

# ---------------------------------------------------------------------------
# Optional profile targets
# ---------------------------------------------------------------------------

.PHONY: up-telegram
up-telegram: ## Add the telegram-bot profile to the running stack
	$(COMPOSE) --profile telegram up -d telegram-bot

.PHONY: up-elk
up-elk: ## Start the full Elastic observability stack on top of the core
	$(COMPOSE) --profile elk up -d --build
	@echo ""
	@echo "ELK stack is starting. It takes ~60 s for Elasticsearch to become healthy."
	@echo "  Elasticsearch:  http://localhost:9200"
	@echo "  Kibana:         http://localhost:5601"
	@echo "  APM Server:     http://localhost:8200"

.PHONY: up-full
up-full: ## Start everything: core + telegram + ELK (heavy on RAM)
	$(COMPOSE) --profile telegram --profile elk up -d --build

.PHONY: down-telegram
down-telegram: ## Stop the telegram-bot service only
	$(COMPOSE) --profile telegram stop telegram-bot

.PHONY: down-elk
down-elk: ## Stop the ELK services only (keep core running)
	$(COMPOSE) --profile elk stop elasticsearch kibana logstash filebeat metricbeat apm-server

.PHONY: profiles-list
profiles-list: ## List which services are in which profile
	@echo ""
	@echo "Default profile (always runs with \`make up\`):"
	@echo "  postgres, redis, backend, frontend, mailhog"
	@echo ""
	@echo "Profile: telegram  (make up-telegram)"
	@echo "  telegram-bot"
	@echo ""
	@echo "Profile: elk       (make up-elk)"
	@echo "  elasticsearch, kibana, logstash, filebeat, metricbeat, apm-server"
	@echo ""

# ---------------------------------------------------------------------------
# Rebuilds
# ---------------------------------------------------------------------------

.PHONY: build
build: ## Build all images without starting containers
	$(COMPOSE) --profile "*" build

.PHONY: rebuild
rebuild: ## Force rebuild of all images (no cache)
	$(COMPOSE) --profile "*" build --no-cache

.PHONY: rebuild-backend
rebuild-backend: ## Rebuild only the backend image
	$(COMPOSE) build --no-cache backend

.PHONY: rebuild-frontend
rebuild-frontend: ## Rebuild only the frontend image
	$(COMPOSE) build --no-cache frontend

# ---------------------------------------------------------------------------
# Shells / exec
# ---------------------------------------------------------------------------

.PHONY: shell-backend
shell-backend: ## Open a bash shell in the backend container
	$(COMPOSE) exec backend /bin/bash

.PHONY: shell-frontend
shell-frontend: ## Open a shell in the frontend container
	$(COMPOSE) exec frontend /bin/sh

.PHONY: shell-db
shell-db: ## Open psql against the postgres container
	$(COMPOSE) exec postgres psql -U $${POSTGRES_USER:-nutrimind} -d $${POSTGRES_DB:-nutrimind}

.PHONY: shell-redis
shell-redis: ## Open redis-cli against the redis container
	$(COMPOSE) exec redis redis-cli

# ---------------------------------------------------------------------------
# Reset / clean
# ---------------------------------------------------------------------------

.PHONY: clean
clean: ## Stop stack and DELETE volumes (wipes DB data and uploads!)
	$(COMPOSE) --profile "*" down -v
	@echo "Volumes removed. Database and uploads are wiped."

.PHONY: prune
prune: ## Remove unused images, networks, and build cache
	docker image prune -f
	docker network prune -f
	docker builder prune -f

.PHONY: nuke
nuke: clean prune ## Full reset: containers, volumes, images, build cache