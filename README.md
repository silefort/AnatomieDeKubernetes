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

version-1/       # Deuxième version : mode déclaratif + boucle de contrôle
  app/
    api_server.py
    app_controller.py
  docker-compose.yml

tests/           # Scripts de validation
Makefile
```

## Versions

### Version 0

Un scheduler naïf : l'`app-manager` expose une API HTTP et déploie les applications sur les noeuds en round-robin via SSH.

### Version 1

Introduction du **mode déclaratif** et de la **boucle de contrôle**.

L'`app-controller` regroupe deux responsabilités :
- **API Server** : reçoit et stocke l'état désiré dans `apps.json`
- **Boucle de contrôle** : tourne en continu sur chaque noeud, compare l'état observé (`docker ps` via SSH) à l'état désiré, et agit (`docker run` / `docker rm`)

## Utilisation

```bash
# Construire les images
make build VERSION=<0|1>

# Démarrer le cluster
make cluster_start VERSION=<0|1>

# Déployer une application
make app_apply VERSION=<0|1> NAME=mon-app IMAGE=nginx:alpine

# Lister les applications
make apps_list VERSION=<0|1>

# Simuler un crash
make app_crash VERSION=<0|1> NAME=mon-app

# Arrêter / démarrer un noeud
make node_stop  VERSION=<0|1> NODE=node-1
make node_start VERSION=<0|1> NODE=node-1

# Afficher les logs
make logs VERSION=<0|1>

# Arrêter le cluster
make cluster_stop VERSION=<0|1>
```
