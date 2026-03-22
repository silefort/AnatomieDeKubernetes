#!/bin/bash
VERSION=${1:-0}
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$VERSION" in
  0)
    # ┌─────────────────────┬─────────────────────┐
    # │  [1] logs           │  [2] watch          │
    # │  app-manager        │  apps en cours      │
    # ├─────────────────────┴─────────────────────┤
    # │  [3] commandes                            │
    # └───────────────────────────────────────────┘
    WIN=$(tmux new-window -n "version-0" -P -F "#{window_index}")

    # Découpage : haut (70%) / bas (30% - commandes)
    tmux split-window -v -l '20%' -t "${WIN}.1"
    # pane 1 = haut, pane 2 = bas (commandes)

    # Découper le haut en deux (logs | watch)
    tmux split-window -h -t "${WIN}.1"

    # Démarrer les logs à gauche
    tmux send-keys -t "${WIN}.1" "cd $DIR && make delete_all VERSION=0 && make cluster_restart VERSION=0 && make logs SERVICE=app-manager VERSION=0" C-m
    tmux send-keys -t "${WIN}.1" "cd $DIR && make logs SERVICE=app-manager VERSION=0" C-m
    # Démarrer le watch à droite
    tmux send-keys -t "${WIN}.2" "cd $DIR && make watch VERSION=0" C-m

    tmux select-pane -t "${WIN}.3"
    tmux send-keys -t "${WIN}.3" "cd $DIR && export VERSION=0 && clear" C-m
    ;;

  1)
    # ┌─────────────────────┬─────────────────────┐
    # │  [1] logs           │  [2] watch          │
    # │  app-controller     │  état désiré +      │
    # │                     │  apps en cours      │
    # ├─────────────────────┴─────────────────────┤
    # │  [3] commandes                            │
    # └───────────────────────────────────────────┘
    WIN=$(tmux new-window -n "version-1" -P -F "#{window_index}")

    # Découpage : haut (80%) / bas (20% - commandes)
    tmux split-window -v -l '20%' -t "${WIN}.1"
    # Découper le haut en deux (logs | watch)
    tmux split-window -h -t "${WIN}.1"

    tmux send-keys -t "${WIN}.1" "cd $DIR && make delete_all VERSION=1 && make cluster_restart VERSION=1 && make logs SERVICE=app-controller VERSION=1" C-m
    tmux send-keys -t "${WIN}.2" "cd $DIR && make watch VERSION=1" C-m

    tmux select-pane -t "${WIN}.3"
    tmux send-keys -t "${WIN}.3" "cd $DIR && export VERSION=1 && clear" C-m
    ;;

  2)
    # ┌─────────────────┬───────────────────────┐
    # │  [1]            │  [3] watch            │
    # │node-binder      │                       │
    # │node-ctrl        │                       │
    # ├─────────────────┤                       │
    # │  [2]            │                       │
    # │ node-1          │                       │
    # └─────────────────┴───────────────────────┘
    # │  [4] commandes                          │
    # └─────────────────────────────────────────┘
    WIN=$(tmux new-window -n "version-2" -P -F "#{window_index}")

    # Découpage : haut (80%) / bas (20% - commandes)
    tmux split-window -v -l '20%' -t "${WIN}.1"
    # Découper le haut en deux (logs | watch)
    tmux split-window -h -l '50%' -t "${WIN}.1"
    # Découper le pane de gauche en 2
    tmux split-window -v -l '30%' -t "${WIN}.1"

    tmux send-keys -t "${WIN}.1" "cd $DIR && make delete_all VERSION=2 && make cluster_restart VERSION=2 && make logs SERVICE=node-binder,node-controller VERSION=2" C-m
    tmux send-keys -t "${WIN}.2" "cd $DIR && sleep 10 && make logs SERVICE=node-1 VERSION=2" C-m
    tmux send-keys -t "${WIN}.3" "cd $DIR && make watch VERSION=2" C-m

    tmux select-pane -t "${WIN}.4"
    tmux send-keys -t "${WIN}.4" "cd $DIR && export VERSION=2 && clear" C-m
    ;;

  *)
    echo "Usage: $0 <VERSION>"
    echo "Versions disponibles: 0, 1, 2"
    exit 1
    ;;
esac
