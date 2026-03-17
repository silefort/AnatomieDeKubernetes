#!/bin/bash

# Lire NODE_NAME depuis le fichier si la variable n'est pas définie
if [ -z "$NODE_NAME" ] && [ -f /etc/node_name ]; then
  NODE_NAME=$(cat /etc/node_name)
fi

if [ "$1" = "ps" ]; then
  /usr/local/bin/docker.orig ps --filter "label=node=$NODE_NAME" "${@:2}"
elif [ "$1" = "run" ]; then
  # Si le noeud est en pause, ne rien faire
  if [ -f "/app/.paused_$NODE_NAME" ]; then
    exit 0
  fi

  # Extraire le nom du container s'il est spécifié avec --name
  name=""
  prev=""
  for arg in "${@:2}"; do
    if [ "$prev" = "--name" ]; then
      name="$arg"
      break
    fi
    prev="$arg"
  done

  # Supprimer le container s'il existe déjà (même arrêté)
  if [ -n "$name" ]; then
    /usr/local/bin/docker.orig rm -f "$name" 2>/dev/null || true
  fi

  /usr/local/bin/docker.orig run --label "type=app" --label "node=$NODE_NAME" "${@:2}"
else
  /usr/local/bin/docker.orig "$@"
fi
