#!/usr/bin/env python3
import time
import os
from utils.shell_utils import shell
from datetime import datetime
from utils.http_utils import get, put

API_SERVER = "http://api-server:8080"
NODE_NAME = os.environ.get("NODE_NAME", "unknown")

apps_voulues = {}
iteration = 0

while True:
    iteration += 1
    debut = time.time()

    # --- 00. Envoyer un heartbeat à l'API Server (silencieux si OK)
    try:
        put(f"{API_SERVER}/node/{NODE_NAME}/heartbeat", {"timestamp": datetime.now().isoformat()})
    except Exception as e:
        print(f"#{iteration} heartbeat échoué ({e})")

    # --- 01. CAPTEUR - Observer l'état actuel ---
    apps_actuelles = {}
    response = shell("docker ps --format '{{.Names}}\t{{.Image}}'")
    applications = response.split('\n') if response else []
    for application in applications:
        name, image = application.split('\t')
        apps_actuelles[name] = image

    # --- 02. ETAT_DESIRE - Lire l'état désiré pour ce noeud ---
    api_error = None
    try:
        response = get(f"{API_SERVER}/apps?nodeName={NODE_NAME}")
        apps_voulues = {app: info["image"] for app, info in response.items()}
    except Exception as e:
        api_error = e

    # --- 03. DETECTEUR - Identifier l'écart ---
    apps_a_demarrer = set(apps_voulues.keys()) - set(apps_actuelles.keys())
    apps_a_arreter = set(apps_actuelles.keys()) - set(apps_voulues.keys())

    if not apps_a_demarrer and not apps_a_arreter and not api_error:
        print(f"#{iteration} {len(apps_voulues)} désirée(s) / {len(apps_actuelles)} en cours — état désiré atteint en {time.time() - debut:.2f}s")
    else:
        if api_error:
            print(f"#{iteration} API server non disponible ({api_error}), utilisation du dernier état connu")
        else:
            print(f"#{iteration} {len(apps_voulues)} désirée(s) / {len(apps_actuelles)} en cours en {time.time() - debut:.2f}s")
        # --- 04. eCTIONNEUR - Appliquer les changements ---
        for app in apps_a_demarrer:
            print(f"#{iteration} démarrage de {app}")
            shell(f"docker run -d --name {app} {apps_voulues[app]}")
        for app in apps_a_arreter:
            print(f"#{iteration} arrêt de {app}")
            shell(f"docker rm -f {app}")

    time.sleep(10)
