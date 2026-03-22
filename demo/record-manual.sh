#!/bin/bash
# Script pour enregistrer une démo manuelle avec asciinema
# Usage: ./demo/record-manual.sh <version>
# Stop: quitter tmux (Ctrl+D dans le dernier pane, ou `tmux kill-session`)

set -e

if [ -n "$TMUX" ]; then
    echo "⚠️  Lance ce script depuis un terminal normal (hors tmux)"
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Exemple: $0 2"
    exit 1
fi

VERSION=$1
SESSION="duck-demo-$$"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$DIR/demo/recordings/version-${VERSION}-$(date +%Y%m%d-%H%M%S).cast"
mkdir -p "$DIR/demo/recordings"

echo "🎬 Enregistrement: $OUTPUT"
echo "ℹ️  Pour stopper: 'tmux kill-session' ou fermer tous les panes (Ctrl+D)"
echo ""
sleep 1

# Créer une session tmux dédiée
tmux new-session -d -s "$SESSION" -x "$(tput cols)" -y "$(tput lines)"

# Configurer les fenêtres dans cette session
bash "$DIR/demo/tmux.sh" "$VERSION"

# Supprimer la fenêtre vide initiale (index 0)
tmux kill-window -t "${SESSION}:0" 2>/dev/null || true

# Enregistrer en s'attachant à la session
asciinema rec "$OUTPUT" -c "tmux attach -t $SESSION"

# Nettoyage au cas où la session tmux serait encore là
tmux kill-session -t "$SESSION" 2>/dev/null || true

echo ""
echo "✅ Enregistrement terminé: $OUTPUT"
echo "Pour rejouer: asciinema play $OUTPUT"
