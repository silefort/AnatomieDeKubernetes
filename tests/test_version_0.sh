#!/bin/bash
set -euo pipefail

VERSION=0
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
for node in node-1 node-2 node-3 app-manager; do
    if wait_for_container "$node"; then
        ok "container $node démarré"
    else
        fail "container $node non démarré"
    fi
done

# cluster_list
run "cluster_list" make cluster_list VERSION=$VERSION

# Attente API
if wait_for_http "http://localhost:8080"; then
    ok "app-manager répond sur :8080"
else
    fail "app-manager ne répond pas sur :8080"
fi

# app_apply
run "app_apply" make app_apply VERSION=$VERSION NAME=test-app IMAGE=nginx:alpine

# Vérification que l'app tourne sur un noeud
sleep 2
if podman ps --filter "label=type=app" --format '{{.Names}}' | grep -q "^test-app$"; then
    ok "app test-app tourne sur un noeud"
else
    fail "app test-app introuvable"
fi

# apps_list
run "apps_list" make apps_list VERSION=$VERSION

# app_crash
run "app_crash" make app_crash VERSION=$VERSION NAME=test-app

# node_stop / node_start
run "node_stop"  make node_stop  VERSION=$VERSION NODE=node-1
run "node_start" make node_start VERSION=$VERSION NODE=node-1

# apps_clean
run "apps_clean" make apps_clean VERSION=$VERSION

# cluster_stop
run "cluster_stop" make cluster_stop VERSION=$VERSION

echo
echo "=== Résultat : ${PASS} OK, ${FAIL} KO ==="
[ $FAIL -eq 0 ]
