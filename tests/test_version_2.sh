#!/bin/bash
set -euo pipefail

VERSION=2
PASS=0
FAIL=0

green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

ok()   { echo -e "${green}[OK]${nc}  $1"; PASS=$((PASS+1)); }
fail() { echo -e "${red}[KO]${nc}  $1"; FAIL=$((FAIL+1)); }

run() {
    local label=$1; shift
    if "$@" > /dev/null 2>&1; then
        ok "$label"
    else
        fail "$label"
    fi
}

wait_for_container() {
    local name=$1
    local retries=15
    while [ $retries -gt 0 ]; do
        if podman ps --format '{{.Names}}' | grep -q "^${name}$"; then
            return 0
        fi
        sleep 1
        retries=$((retries-1))
    done
    return 1
}

wait_for_http() {
    local url=$1
    local retries=20
    while [ $retries -gt 0 ]; do
        if curl -s -o /dev/null "$url" 2>&1; then
            return 0
        fi
        sleep 1
        retries=$((retries-1))
    done
    return 1
}

wait_for_app() {
    local name=$1
    local retries=${2:-30}
    while [ $retries -gt 0 ]; do
        if podman ps --filter "label=type=app" --format '{{.Names}}' | grep -q "^${name}$"; then
            return 0
        fi
        sleep 1
        retries=$((retries-1))
    done
    return 1
}

wait_for_app_gone() {
    local name=$1
    local retries=30
    while [ $retries -gt 0 ]; do
        if ! podman ps --filter "label=type=app" --format '{{.Names}}' | grep -q "^${name}$"; then
            return 0
        fi
        sleep 1
        retries=$((retries-1))
    done
    return 1
}

echo "=== Test version-$VERSION ==="
echo

# Sans VERSION ça doit planter
if ! make cluster_start > /dev/null 2>&1; then
    ok "make sans VERSION échoue"
else
    fail "make sans VERSION aurait dû échouer"
fi

# Nettoyage initial
run "delete_all" make delete_all VERSION=$VERSION

# Build
run "build" make build VERSION=$VERSION

# Démarrage cluster
run "cluster_start" make cluster_start VERSION=$VERSION

# Attente des containers
for container in api-server node-binder node-controller node-1 node-2 node-3; do
    if wait_for_container "$container"; then
        ok "container $container démarré"
    else
        fail "container $container non démarré"
    fi
done

# Attente API
if wait_for_http "http://localhost:8080"; then
    ok "api-server répond sur :8080"
else
    fail "api-server ne répond pas sur :8080"
fi

# Vérification des heartbeats (les noeuds envoient bien leurs heartbeats)
sleep 15
NODES_JSON=$(curl -s http://localhost:8080/nodes)
for node in node-1 node-2 node-3; do
    if echo "$NODES_JSON" | grep -q "\"$node\""; then
        ok "heartbeat reçu de $node"
    else
        fail "aucun heartbeat reçu de $node"
    fi
done

# app_apply (déclare l'état désiré)
run "app_apply" make app_apply VERSION=$VERSION NAME=test-app IMAGE=nginx:alpine

# Attente binding + réconciliation
if wait_for_app "test-app"; then
    ok "app test-app démarrée par la boucle de réconciliation"
else
    fail "app test-app introuvable après réconciliation"
fi

# apps_list
run "apps_list" make apps_list VERSION=$VERSION

# app_crash + self-healing
run "app_crash" make app_crash VERSION=$VERSION NAME=test-app

if wait_for_app "test-app"; then
    ok "self-healing : test-app redémarrée après crash"
else
    fail "self-healing : test-app non redémarrée après crash"
fi

# node_stop : le node-controller doit détecter la panne et reschedule l'app
NODE_DE_TEST=$(podman ps --filter "label=type=app" --filter "name=test-app" --format '{{.Labels.node}}' | head -1)
run "node_stop" make node_stop VERSION=$VERSION NODE=$NODE_DE_TEST

# Attente du timeout heartbeat (20s) + détection + rebinding + réconciliation
echo "  (attente du rescheduling après panne de $NODE_DE_TEST...)"
if wait_for_app_gone "test-app"; then
    ok "test-app retirée du noeud en panne"
else
    fail "test-app toujours sur le noeud en panne"
fi

if wait_for_app "test-app" 60; then
    ok "rescheduling : test-app redémarrée sur un autre noeud"
else
    fail "rescheduling : test-app non redémarrée après panne noeud"
fi

run "node_start" make node_start VERSION=$VERSION NODE=$NODE_DE_TEST

# apps_clean
run "apps_clean" make apps_clean VERSION=$VERSION

# cluster_stop
run "cluster_stop" make cluster_stop VERSION=$VERSION

echo
echo "=== Résultat : ${PASS} OK, ${FAIL} KO ==="
[ $FAIL -eq 0 ]
