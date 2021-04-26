#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

rm -rf tmp/hello-world-debian-package
cp -r /vagrant/hello-world-debian-package tmp
cd tmp/hello-world-debian-package

#
# test the apt repository.

# create the hello-world package.
# see https://www.debian.org/doc/manuals/debmake-doc/ch04.en.html
# see https://www.debian.org/doc/debian-policy/ch-source.html
# see apt-get source dash
apt-get install -y devscripts debmake debhelper dpkg-dev
pushd hello-world
debuild -i -us -uc -b
popd

# upload.
# see https://help.sonatype.com/repomanager3/formats/apt-repositories
apt-get install -y curl
curl \
    --fail \
    --show-error \
    --user 'alice.doe:password' \
    --header 'Content-Type: multipart/form-data' \
    --data-binary @hello-world_1.0.0_amd64.deb \
    https://$nexus_domain/repository/apt-hosted/

# trust the apt-hosted key.
apt-key add /vagrant/shared/apt-hosted-public.key

# install the hello-world package.
echo "deb [arch=amd64] https://$nexus_domain/repository/apt-hosted focal main" >/etc/apt/sources.list.d/nexus-apt-hosted.list
apt-get update
apt-get install -y hello-world
apt-cache show hello-world
apt-cache policy hello-world
hello-world
