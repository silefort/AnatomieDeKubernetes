import requests

def get(url):
    return requests.get(url, timeout=5).json()

def put(url, data):
    return requests.put(url, json=data, timeout=5)
