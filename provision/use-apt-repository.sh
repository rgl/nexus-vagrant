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
# see https://help.sonatype.com/en/apt-repositories.html
apt-get install -y curl
curl \
    --fail \
    --show-error \
    --user 'alice.doe:password' \
    --header 'Content-Type: multipart/form-data' \
    --data-binary @hello-world_1.0.0_amd64.deb \
    https://$nexus_domain/repository/apt-hosted/

# import the apt-hosted key.
nexus_apt_hosted_keyring_path="/etc/apt/keyrings/$nexus_domain-apt-hosted.gpg"
gpg --dearmor -o "$nexus_apt_hosted_keyring_path" </vagrant/shared/apt-hosted-public.key

# configure the apt-hosted repository.
echo "deb [arch=amd64 signed-by=$nexus_apt_hosted_keyring_path] https://$nexus_domain/repository/apt-hosted jammy main" >"/etc/apt/sources.list.d/$nexus_domain-apt-hosted.list"
# NB for some odd reason, nexus 3.84.0-03, does not immediately sign the
#    repository metadata after a package is uploaded, so to prevent the
#    following error, we loop until apt-get update succeeds.
#       E: The repository 'https://nexus.example.com/repository/apt-hosted jammy Release' is not signed.
# see https://github.com/sonatype/nexus-public/issues/725
while ! apt-get update; do sleep 5; done

# install the hello-world package.
apt-get install -y hello-world
apt-cache show hello-world
apt-cache policy hello-world
hello-world
