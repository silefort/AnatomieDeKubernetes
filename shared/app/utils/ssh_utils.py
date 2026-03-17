#!/usr/bin/env python3
import logging
import paramiko

_TRACEBACK_BOILERPLATE = (
    'Traceback (most recent call last):',
    'During handling of the above exception, another exception occurred:',
)

class _NoIndentedLines(logging.Filter):
    def filter(self, record):
        msg = record.getMessage()
        if not msg or msg.startswith((' ', '\t')):
            return False
        if msg in _TRACEBACK_BOILERPLATE:
            return False
        if msg.endswith(('Error', 'Exception')):
            return False
        return True

_handler = logging.StreamHandler()
_handler.setFormatter(logging.Formatter("%(name)s: %(message)s"))
_handler.addFilter(_NoIndentedLines())
_logger = logging.getLogger("paramiko")
_logger.handlers = [_handler]
_logger.propagate = False

def ssh(node, cmd, timeout=10):
    """Execute une commande sur un noeud via SSH avec timeout"""
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(node, username="root", password="root", timeout=timeout)
        _, stdout, _ = client.exec_command(cmd)
        return stdout.read().decode().strip()
    except Exception as e:
        print(f"[ssh] Erreur sur {node}: {e}")
        return ""
