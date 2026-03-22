# Anatomie de Kubernetes

---

**Duck Conf 2026** · *Anatomie de Kubernetes : ce qu'on aurait aimé comprendre plus tôt* · avec [Léa Boyer](https://www.linkedin.com/in/l%C3%A9a-boyer-408641189/) · [Slides →](./Slides_Duck_Conf_20260324.pdf)

---

Ce projet est un compagnon au Talk "Anatomie de Kubernetes : ce qu'on aurait aimé comprendre plus tôt" donné avec Léa Boyer à la Duck Conf 2026.

Dans ce talk nous avons choisi de réimplémenter une version simplifiée d'un orchestrateur de containers pour comprendre comment et pourquoi Kubernetes a été implémenté comme il est.

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

Un gestionnaire d'applications naïf : l'`app-manager` expose une API HTTP et déploie les applications sur les noeuds en round-robin via SSH.

### Version 1

Introduction du **mode déclaratif**, de la **boucle de contrôle** et d'une approche **level trigger**

L'`app-manager` regroupe deux responsabilités dans un composant centralisé :
- **`api_server`** : reçoit et stocke l'état désiré dans `apps.json`
- **`app_controller`** : tourne en continu, interroge chaque noeud via SSH pour observer l'état réel, et applique les corrections (`docker run` / `docker rm`)

### Version 2

Séparation de l'`app-manager` en plusieurs **composants autonomes** qui discutent via une **api centralisée**

Les responsabilités sont éclatées sur plusieurs contrôleurs indépendants :
- **`api_server`** : stocke l'état désiré (`apps.json`) et reçoit les heartbeats des noeuds (`nodes.json`)
- **`app_controller`** : tourne sur chaque noeud, envoie un heartbeat périodique à l'API Server et reconcilie l'état local
- **`node_binder`** : détecte les applications sans noeud assigné et les attribue en round-robin
- **`node_controller`** : surveille les heartbeats, détecte les noeuds en panne et "désassigne" leurs applications pour qu'elles soient réassignées

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

## Références

### Kubernetes :
- [Kubernetes - The documentary](https://www.youtube.com/watch?v=BE77h7dmoQU)
- [Joe Beda explains some of the inner workings of Kubernetes - Joe Beda](https://www.cncf.io/blog/2017/11/07/joe-beda-explains-inner-workings-kubernetes)
- [The Technical History of Kubernetes - Brian Grant](https://itnext.io/the-technical-history-of-kubernetes-2fe1988b522a)
- [Borg, Omega, and Kubernetes - Google](https://static.googleusercontent.com/media/research.google.com/fr//pubs/archive/44843.pdf)
- [Understanding Kubernetes Through Real-World Phenomena and Analogies - Lucas Käldström](https://www.youtube.com/watch?v=GpJz-Ab8R9M)
- [Two reasons Kubernetes is so complex - Nelson Elhage](https://buttondown.com/nelhage/archive/two-reasons-kubernetes-is-so-complex)
- [Fundamentals of Declarative Application Management in Kubernetes - Zhang Lei](https://www.alibabacloud.com/blog/fundamentals-of-declarative-application-management-in-kubernetes_596265)
- [Kubernetes Design Principles - Kubernetes Github repository](https://github.com/kubernetes/design-proposals-archive/blob/main/architecture/principles.md)
- [Building Kubernetes (a lite version) from scratch in Go - Owumi Festus](https://medium.com/@owumifestus/building-kubernetes-a-lite-version-from-scratch-in-go-7156ed1fef9e)
- [The Kubernetes Resource Model (KRM) - Kubernetes Github repository](https://github.com/kubernetes/design-proposals-archive/blob/main/architecture/resource-management.md)

### Level Trigger vs. Edge Trigger :
- [Level Triggering and Reconciliation in Kubernetes - @jbows](https://hackernoon.com/level-triggering-and-reconciliation-in-kubernetes-1f17fe30333d)

### Control Theory :
- [Applying control theory concepts in software applications - Dr. Wolfgang Winter](https://www.theserverside.com/feature/Applying-control-theory-concepts-in-software-applications)
- [Reconciliation Pattern, Control Theory and Cluster API: The Holy Trinity - Sachin Singhy](https://archive.fosdem.org/2023/schedule/event/goreconciliation/)
- [Desired State How React, Kubernetes and control Theory have lots in common - Branislav Jenco](https://www.youtube.com/watch?v=TENp6xaSd3M)
- [Control Theory in Container Fleet Management - Vallery Lancey](https://www.infoq.com/presentations/controllers-observing-systems/)

### Promise Theory :
- [Thinking in Promises - Mark Burgess](https://api.pageplace.de/preview/DT0400.9781491918494_A25184803/preview-9781491918494_A25184803.pdf)
