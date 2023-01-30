#!/bin/bash
set -euxo pipefail

docker_version="${1:-20.10.23}"; shift || true
registry_proxy_domain="${1:-$(hostname --fqdn)}"; shift || true
# NB as-of docker 19.03.8, there is still no way to specify a registry mirror credentials,
#    as such, we cannot use our docker-group registry, instead we must use the docker-proxy
#    registry and allow anonymous access to it.
#    see https://github.com/moby/moby/issues/30880
registry_proxy_host="$registry_proxy_domain:5002"
registry_proxy_url="https://$registry_proxy_host"

# prevent apt-get et al from asking questions.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# make sure the package index cache is up-to-date before installing anything.
apt-get update

# install docker.
# see https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-using-the-repository
apt-get install -y apt-transport-https software-properties-common
wget -qO- https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-cache madison docker-ce
docker_version="$(apt-cache madison docker-ce | awk "/$docker_version~/{print \$3}")"
apt-get install -y "docker-ce=$docker_version" "docker-ce-cli=$docker_version" containerd.io

# configure it.
systemctl stop docker
cat >/etc/docker/daemon.json <<'EOF'
{
    "experimental": false,
    "debug": false,
    "log-driver": "journald",
    "labels": [
        "os=linux"
    ],
    "hosts": [
        "fd://"
    ],
    "containerd": "/run/containerd/containerd.sock",
    "registry-mirror": "$registry_proxy_url"
}
EOF
# start docker without any command line flags as its entirely configured from daemon.json.
install -d /etc/systemd/system/docker.service.d
cat >/etc/systemd/system/docker.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF
systemctl daemon-reload
systemctl start docker

# let the vagrant user manage docker.
usermod -aG docker vagrant

# kick the tires.
ctr version
docker version
docker info
