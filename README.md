# Anatomie de Kubernetes

Ce projet implémente une version simplifiée d'un orchestrateur de containers pour comprendre de l'intérieur ce que fait Kubernetes.

Le cluster est simulé localement avec Podman — les noeuds sont des containers, les applications aussi.

## Prérequis

- `podman` + `slirp4netns`, `fuse-overlayfs`, `uidmap` (pour le mode rootless)
- `podman-compose`
- `make`, `curl`

Le socket Podman doit être actif pour l'utilisateur courant :

```bash
systemctl --user enable --now podman.socket
```

Le projet a été principalement testé avec Podman. Il devrait fonctionner avec Docker en passant `DOCKER=docker DOCKER_COMPOSE=docker-compose` aux commandes `make`.

## Structure du projet

```
shared/          # Image Docker de base et utilitaires Python communs à toutes les versions
  Dockerfile
  utils/         # Librairie partagée (SSH, logging)

version-0/       # Première version de l'orchestrateur
  app_manager.py
  docker-compose.yml

tests/           # Scripts de validation
Makefile
```

## Versions

### Version 0

Un scheduler naïf : l'`app-manager` expose une API HTTP et déploie les applications sur les noeuds en round-robin via SSH.

## Utilisation

```bash
# Construire les images
make build VERSION=0

# Démarrer le cluster
make cluster_start VERSION=0

# Déployer une application
make app_apply VERSION=0 NAME=mon-app IMAGE=nginx:alpine

# Lister les applications
make apps_list VERSION=0

# Simuler un crash
make app_crash VERSION=0 NAME=mon-app

# Arrêter / démarrer un noeud
make node_stop  VERSION=0 NODE=node-1
make node_start VERSION=0 NODE=node-1

# Afficher les logs
make logs VERSION=0

# Arrêter le cluster
make cluster_stop VERSION=0
```
