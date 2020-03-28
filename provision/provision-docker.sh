#!/bin/bash
set -eux

# NB execute apt-cache madison docker-ce to known the available versions.
docker_version="${1:-5:19.03.8~3-0~ubuntu-bionic}"; shift || true
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

# install docker.
# see https://docs.docker.com/install/linux/docker-ce/ubuntu/
apt-get install -y apt-transport-https software-properties-common gnupg2
wget -qO- https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y "docker-ce=$docker_version" "docker-ce-cli=$docker_version" containerd.io

# configure it.
cat >/etc/docker/daemon.json <<EOF
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
systemctl restart docker

# let the vagrant user manage docker.
usermod -aG docker vagrant

# kick the tires.
ctr version
docker version
docker info
