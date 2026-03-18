import subprocess

def shell(command):
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=None, text=True)
    return result.stdout.strip()
