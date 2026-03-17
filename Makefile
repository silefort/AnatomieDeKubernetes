DOCKER ?= podman
DOCKER_COMPOSE ?= podman-compose
ifndef VERSION
$(error VERSION non défini. Usage: make <cible> VERSION=<0|1|2>)
endif

COMPOSE_FLAGS = -f version-$(VERSION)/docker-compose.yml -p version-$(VERSION)

.PHONY: help build cluster_start cluster_stop cluster_restart app_create app_apply app_crash apps_clean apps_list node_stop node_start node_ssh logs watch _watch_display delete_all

help:
	@echo "Commandes disponibles (VERSION=<0|1|2>):"
	@echo "  make cluster_start                       - Demarre le cluster"
	@echo "  make cluster_stop                        - Arrete le cluster"
	@echo "  make cluster_restart                     - Redemarre le cluster"
	@echo "  make app_apply NAME=<name> IMAGE=<image> - Déclare une app"
	@echo "  make app_crash NAME=<name>               - Simule un crash (OOM kill)"
	@echo "  make apps_clean                          - Supprime tous les apps"
	@echo "  make apps_list                           - Liste les apps"
	@echo "  make node_stop NODE=<node>               - Pause un noeud"
	@echo "  make node_start NODE=<node>              - Unpause un noeud"
	@echo "  make node_ssh NODE=<node>                - Se connecte a un noeud"
	@echo "  make logs                                - Affiche les logs avec couleurs"
	@echo "  make delete_all                          - Supprime tous les containers"

build:
	$(DOCKER_COMPOSE) $(COMPOSE_FLAGS) build

cluster_start:
	$(DOCKER_COMPOSE) $(COMPOSE_FLAGS) up -d

cluster_stop:
	@$(DOCKER) unpause $$($(DOCKER) ps -aq --filter status=paused) 2>/dev/null || true
	@rm -f version-$(VERSION)/.paused_*
	$(DOCKER_COMPOSE) $(COMPOSE_FLAGS) down -t 0

cluster_restart: cluster_stop apps_clean cluster_start
	@echo "=============================="
	@$(DOCKER) ps -a --format "{{.Names}}\t{{.Labels.type}}" | grep -E "node|control-plane" | awk '{ print $1 }' | sort

logs:
	clear
	@NC='\033[0m'; \
	colorize_logs() { \
		local service=$$1; \
		local color=$$2; \
		if $(DOCKER) ps --format '{{.Names}}' | grep -q "^$${service}$$"; then \
			$(DOCKER) logs -f --tail 20 "$${service}" 2>&1 | while IFS= read -r line; do \
				printf "%b[%s]%b %s\n" "$${color}" "$${service}" "$${NC}" "$$line"; \
			done; \
		fi; \
	}; \
	colorize_logs "app-manager" '\033[0;34m' & \
	colorize_logs "node-1"      '\033[0;31m' & \
	colorize_logs "node-2"      '\033[0;32m' & \
	colorize_logs "node-3"      '\033[0;33m' & \
	wait

app_create: app_apply

app_apply:
	@test -n "$(NAME)" || (echo "Erreur: NAME non défini. Usage: make app_apply NAME=<name> IMAGE=<image>" && false)
	@test -n "$(IMAGE)" || (echo "Erreur: IMAGE non défini. Usage: make app_apply NAME=<name> IMAGE=<image>" && false)
	@curl -s -X PUT http://localhost:8080/app/$(NAME) \
		-H "Content-Type: application/json" \
		-d '{"image": "$(IMAGE)"}' | python3 -m json.tool

app_crash:
	@test -n "$(NAME)" || (echo "Erreur: NAME non défini. Usage: make app_crash NAME=<name>" && false)
	@NODE=$$($(DOCKER) ps --filter "name=$(NAME)" --filter "label=type=app" --format "{{.Labels.node}}" | head -1); \
	test -n "$$NODE" || (echo "Erreur: Application $(NAME) introuvable" && false); \
	echo "make node_ssh NODE=$$NODE"; \
	echo "docker kill $(NAME)"; \
	$(DOCKER) kill $(NAME) > /dev/null 2>&1

apps_clean:
	@$(DOCKER) rm -f $$($(DOCKER) ps -aq --filter "label=type=app") 2>/dev/null || true
	echo '{}' > version-$(VERSION)/apps.json
	echo '{}' > version-$(VERSION)/nodes.json

apps_list:
	@echo "APP\tNODE\tUPTIME"
	@$(DOCKER) ps --filter "label=type=app" --format "{{.Names}}\t{{.Labels.node}}\t{{.RunningFor}}"

node_stop:
	@test -n "$(NODE)" || (echo "Erreur: NODE non défini. Usage: make node_stop NODE=<node>" && false)
	@touch version-$(VERSION)/.paused_$(NODE)
	@$(DOCKER) rm -f $$($(DOCKER) ps -aq --filter "label=type=app" --filter "label=node=$(NODE)") > /dev/null 2>&1 || true
	@$(DOCKER) pause $(NODE) > /dev/null
	@echo "Noeud $(NODE) stoppé"

node_start:
	@test -n "$(NODE)" || (echo "Erreur: NODE non défini. Usage: make node_start NODE=<node>" && false)
	@rm -f version-$(VERSION)/.paused_$(NODE)
	@$(DOCKER) unpause $(NODE) > /dev/null
	@echo "Noeud $(NODE) démarré"

node_ssh:
	@test -n "$(NODE)" || (echo "Erreur: NODE non défini. Usage: make node_ssh NODE=<node>" && false)
	@$(DOCKER) exec -it $(NODE) /bin/bash

watch:
	watch -t -n 2 "VERSION=$(VERSION) $(MAKE) --no-print-directory _watch_display"

_watch_display:
	@echo "=== APPS EN COURS ===" ; \
	for node in node-1 node-2 node-3; do \
		echo ; \
		echo "**$$node**" ; \
		apps=$$($(DOCKER) ps --filter "label=type=app" --filter "label=node=$$node" --format "  {{.Names}}\t{{.RunningFor}}"); \
		if [ -n "$$apps" ]; then \
			echo "$$apps"; \
		else \
			echo "  (aucune app)"; \
		fi; \
	done

delete_all:
	@$(DOCKER) unpause $$($(DOCKER) ps -aq --filter status=paused) 2>/dev/null || true
	@$(DOCKER) kill --signal KILL -a
	@$(DOCKER) rm -f $$($(DOCKER) ps -aq) 2>/dev/null || true
	@$(DOCKER) kill --signal KILL -a
	@$(DOCKER) rm -f $$($(DOCKER) ps -aq) 2>/dev/null || true
	$(DOCKER) ps -a
