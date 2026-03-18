#!/usr/bin/env python3
import json, os
from json import JSONDecodeError
from flask import Flask, jsonify, request
from utils.log_helper import setup_flask_logger

setup_flask_logger("api-server")

app = Flask(__name__)
APPS_FILE = "/app/apps.json"
NODES_FILE = "nodes.json"

@app.route('/apps', methods=['GET'])
def get_apps():
    node_filter = request.args.get('nodeName')
    with open(APPS_FILE, 'r') as f:
        apps = json.load(f)
    return jsonify({name: {"image": info["image"]} for name, info in apps.items() if info["node"] == node_filter})

@app.route('/app/<name>', methods=['PUT'])
def update_app(name):
    with open(APPS_FILE, 'r') as f:
        apps = json.load(f)

    if name not in apps:
        apps[name] = {"image": "", "node": ""}

    if "image" in request.json:
        apps[name]["image"] = request.json["image"]
    if "node" in request.json:
        apps[name]["node"] = request.json["node"]

    with open(APPS_FILE, 'w') as f:
        json.dump(apps, f, indent=2)

    print(f"Mise à jour de '{name}' : {apps[name]}")
    return jsonify({"app": name, **apps[name]})

def _read_nodes():
    try:
        return json.load(open(NODES_FILE)) if os.path.exists(NODES_FILE) else {}
    except JSONDecodeError:
        return {}

@app.route('/node/<name>/heartbeat', methods=['PUT'])
def heartbeat(name):
    nodes = _read_nodes()
    nodes[name] = request.json['timestamp']
    tmp = NODES_FILE + ".tmp"
    with open(tmp, 'w') as f:
        json.dump(nodes, f)
    os.replace(tmp, NODES_FILE)
    return jsonify({"node": name, "heartbeat": nodes[name]})

@app.route('/nodes', methods=['GET'])
def get_nodes():
    return jsonify(_read_nodes())

app.run(host='0.0.0.0', port=8080)
