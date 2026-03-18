#!/usr/bin/env python3
import time
from datetime import datetime
from utils.http_utils import get, put

API_SERVER = "http://api-server:8080"
HEARTBEAT_TIMEOUT = 20  # secondes — si plus de 20s sans heartbeat, le noeud est considéré down
iteration = 0

while True:
    iteration += 1
    debut = time.time()
    now = datetime.now()
    api_error = None
    try:
        nodes = get(f"{API_SERVER}/nodes")
    except Exception as e:
        api_error = e
        nodes = {}

    # --- 02. ETAT_DESIRE - Implicite, aucune application ne doit être sur un noeud considéré comme "down"---

    # --- 03. DETECTEUR - Identifier les noeuds down ---
    noeuds_down = [
        node for node, timestamp in nodes.items()
        if (now - datetime.fromisoformat(timestamp)).total_seconds() > HEARTBEAT_TIMEOUT
    ]

    if api_error:
        print(f"#{iteration} API server non disponible ({api_error})")
    elif not noeuds_down:
        print(f"#{iteration} {len(nodes)} noeud(s) en ligne en {time.time() - debut:.2f}s")
    else:
        print(f"#{iteration} noeud(s) hors ligne : {', '.join(noeuds_down)}")
        # --- 04. ACTIONNEUR - retirer les noeuds aux applications dont le noeud est down ---
        for node in noeuds_down:
            try:
                apps = get(f"{API_SERVER}/apps?nodeName={node}")
            except Exception as e:
                print(f"#{iteration} impossible de récupérer les apps de '{node}' ({e})")
                continue
            print(f"#{iteration} {len(apps)} app(s) à détacher de {node}")
            for app in apps:
                try:
                    put(f"{API_SERVER}/app/{app}", {"node": ""})
                    print(f"#{iteration} {node} détaché de {app}")
                except Exception as e:
                    print(f"#{iteration} impossible de retirer '{app}' de '{node}' ({e})")
        print(f"#{iteration} {len(noeuds_down)} noeud(s) traité(s) en {time.time() - debut:.2f}s")
    time.sleep(10)
