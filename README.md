# Anatomie de Kubernetes

---

**Duck Conf 2026** · *Anatomie de Kubernetes : ce qu'on aurait aimé comprendre plus tôt* · avec [Léa Boyer](https://www.linkedin.com/in/l%C3%A9a-boyer-408641189/) · [Slides →](./Slides_Duck_Conf_20260324.pdf)

---

Ce projet implémente une version simplifiée d'un orchestrateur de containers pour comprendre en implémentant comment fonctionne Kubernetes

Le cluster est simulé localement avec Podman, les noeuds sont des containers, les applications aussi (`podman ps` permet de voir à plat les noeuds et les applications qui tournent)

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
  utils/         # Librairie partagée (HTTP, ssh, shell, logging)

version-0/       # Version 0 : scheduler impératif
  app_manager.py
  docker-compose.yml

version-1/       # Version 1 : mode déclaratif + boucle de contrôle
  api_server.py
  app_controller.py
  docker-compose.yml

version-2/       # Version 2 : architecture distribuée + tolérance aux pannes
  api_server.py
  app_controller.py
  node_binder.py
  node_controller.py
  docker-compose.yml

tests/           # Scripts de validation
Makefile
```

## Versions

### Version 0

Un scheduler naïf : l'`app-manager` expose une API HTTP et déploie les applications sur les noeuds en round-robin via SSH.

### Version 1

Introduction du **mode déclaratif** et de la **boucle de contrôle**.

L'`app-manager` regroupe deux responsabilités dans un seul composant centralisé :
- **`api_server`** : reçoit et stocke l'état désiré dans `apps.json`
- **`app_controller`** : tourne en continu, interroge chaque noeud via SSH pour observer l'état réel, et applique les corrections (`docker run` / `docker rm`)

### Version 2

Introduction de l'**architecture distribuée** et de la **tolérance aux pannes**.

Les responsabilités sont éclatées sur plusieurs contrôleurs indépendants :
- **`api_server`** : stocke l'état désiré (`apps.json`) et reçoit les heartbeats des noeuds (`nodes.json`)
- **`app_controller`** : tourne sur chaque noeud, envoie un heartbeat périodique à l'API Server et reconcilie l'état local
- **`node_binder`** : détecte les applications sans noeud assigné et les attribue en round-robin
- **`node_controller`** : surveille les heartbeats, détecte les noeuds en panne et libère leurs applications pour qu'elles soient réassignées

## Utilisation

```bash
# Construire les images
make build VERSION=<0|1|2>

# Démarrer le cluster
make cluster_start VERSION=<0|1|2>

# Déployer une application
make app_apply VERSION=<0|1|2> NAME=mon-app IMAGE=nginx:alpine

# Lister les applications
make apps_list VERSION=<0|1|2>

# Simuler un crash
make app_crash VERSION=<0|1|2> NAME=mon-app

# Arrêter / démarrer un noeud
make node_stop  VERSION=<0|1|2> NODE=node-1
make node_start VERSION=<0|1|2> NODE=node-1

# Afficher les logs
make logs VERSION=<0|1|2>

# Arrêter le cluster
make cluster_stop VERSION=<0|1|2>
```
