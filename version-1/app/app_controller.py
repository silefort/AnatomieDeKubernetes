#!/usr/bin/env python3
import json
import time
from utils.ssh_utils import ssh

NODES = ["node-1", "node-2", "node-3"]
APPS_FILE = "/app/apps.json"
compteur_node = 0
iteration = 0

while True:
    iteration += 1
    debut = time.time()
    # CAPTEUR
    apps_actuelles = {}
    for node in NODES:
        containers = ssh(node, "docker ps --format '{{.Names}}'")
        for container in containers.split('\n'):
            if container:
                apps_actuelles[container] = node
    print(f"#{iteration} capteur: {len(apps_actuelles)} app(s) en cours")

    # ETAT DESIRE
    with open(APPS_FILE, 'r') as f:
        apps = json.load(f)
    apps_voulues = {nom: info["image"] for nom, info in apps.items()}

    # DETECTEUR
    apps_a_demarrer = set(apps_voulues.keys()) - set(apps_actuelles.keys())
    apps_a_arreter = set(apps_actuelles.keys()) - set(apps_voulues.keys())

    if not apps_a_demarrer and not apps_a_arreter:
        print(f"#{iteration} état désiré atteint ({len(apps_voulues)} app(s))")
    else:
        print(f"#{iteration} écart détecté: {len(apps_a_demarrer)} à démarrer, {len(apps_a_arreter)} à arrêter")

    # ACTIONNEUR
    for app in apps_a_demarrer:
        node = NODES[compteur_node % len(NODES)]  # ← Décision de scheduling
        compteur_node += 1
        image = apps_voulues[app]
        print(f"#{iteration} démarrage de {app} sur {node}")
        ssh(node, f"docker run -d --name {app} {image}")

    for app in apps_a_arreter:
        node = apps_actuelles[app]
        print(f"#{iteration} arrêt de {app} (était sur {node})")
        ssh(node, f"docker stop {app} && docker rm {app}")

    print(f"#{iteration} réconciliation terminée en {time.time() - debut:.2f}s")

    time.sleep(7)
