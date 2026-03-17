FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y openssh-server curl && \
    rm -rf /var/lib/apt/lists/*

# Installation Docker CLI (fonctionne avec le socket Podman)
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-24.0.7.tgz | \
    tar xz --strip-components=1 -C /usr/local/bin docker/docker && \
    mv /usr/local/bin/docker /usr/local/bin/docker.orig

# Installation du wrapper docker
COPY shared/docker-wrapper.sh /usr/local/bin/docker
RUN chmod +x /usr/local/bin/docker

# Configuration SSH
RUN mkdir -p /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Dependances Python
COPY shared/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

WORKDIR /app
