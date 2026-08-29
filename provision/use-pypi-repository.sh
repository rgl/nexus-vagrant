#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

rm -rf tmp/hello-world-pypi-package
install -d tmp
cp -r /vagrant/hello-world-pypi-package tmp
cd tmp/hello-world-pypi-package

# create the venv.
apt-get install -y python3-venv
rm -rf .venv
python3 -m venv .venv
set +x && source .venv/bin/activate && set -x

# install the package build requirements.
# see https://pypi.org/project/build/
# see https://pypi.org/project/twine/
python3 -m pip install -r build-requirements.txt

# build the hello_world package.
# see https://packaging.python.org/en/latest/tutorials/packaging-projects/
# see https://help.sonatype.com/en/pypi-repositories.html
python3 -m build --wheel

# publish the package.
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
cat >.venv/twine.conf <<EOF
[pypi]
repository: https://$nexus_domain/repository/pypi-hosted/
username: alice.doe
password: password
EOF
twine upload --non-interactive --config-file .venv/twine.conf dist/*
unset CURL_CA_BUNDLE

# deactivate the venv.
set +x && deactivate && set -x

# use the hello-world package.
rm -rf .venv
python3 -m venv .venv
set +x && source .venv/bin/activate && set -x
cat >.venv/pip.conf <<EOF
[global]
index = https://$nexus_domain/repository/pypi-hosted/pypi
index-url = https://$nexus_domain/repository/pypi-hosted/simple
cert = /etc/ssl/certs/ca-certificates.crt
EOF
python3 -m pip install hello-world
python3 <<'EOF'
import hello_world

hello_world.greet('World')
EOF
set +x && deactivate && set -x
