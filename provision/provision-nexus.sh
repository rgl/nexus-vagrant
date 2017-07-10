#!/bin/bash
set -eux


# install java.
apt-get install -y default-jre


# add the nexus user.
groupadd --system nexus
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup nexus \
    --home /opt/nexus \
    nexus
install -d -o root -g nexus -m 750 /opt/nexus


# download and install nexus.
pushd /opt/nexus
# see http://www.sonatype.com/download-oss-sonatype
# see https://books.sonatype.com/nexus-book/3.4/reference/index.html
nexus_tarball=nexus-3.4.0-02-unix.tar.gz
nexus_download_url=https://sonatype-download.global.ssl.fastly.net/nexus/3/$nexus_tarball
nexus_download_sha1=27133f1d6cc6c6c1731a8cf3aa329059a5a86e01
wget -q $nexus_download_url
if [ "$(sha1sum $nexus_tarball | awk '{print $1}')" != "$nexus_download_sha1" ]; then
    echo "downloaded $nexus_download_url failed the checksum verification"
    exit 1
fi
tar xf $nexus_tarball --strip-components 1
rm $nexus_tarball
chmod 700 nexus3
chown -R nexus:nexus nexus3
install -d -o nexus -g nexus -m 700 .java # java preferences are saved here (the default java.util.prefs.userRoot preference).
install -d -o nexus -g nexus -m 700 nexus3/etc
grep -v -E '\s*##.*' etc/nexus-default.properties >nexus3/etc/nexus.properties
sed -i -E 's,(application-host=).+,\1127.0.0.1,g' nexus3/etc/nexus.properties
sed -i -E 's,nexus-pro-,nexus-oss-,g' nexus3/etc/nexus.properties
diff -u etc/nexus-default.properties nexus3/etc/nexus.properties || true
sed -i -E 's,\.\./sonatype-work/,,g' bin/nexus.vmoptions
popd


# start nexus.
cat >/etc/systemd/system/nexus.service <<'EOF'
[Unit]
Description=Nexus
After=network.target

[Service]
Type=simple
User=nexus
Group=nexus
ExecStart=/opt/nexus/bin/nexus run
WorkingDirectory=/opt/nexus
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable nexus
systemctl start nexus

# install tools.
apt-get install -y --no-install-recommends httpie
apt-get install -y --no-install-recommends jq

# wait for nexus to come up.
bash -c 'while [[ "$(wget -qO- http://localhost:8081/service/extdirect/poll/rapture_State_get | jq -r .data.data.status.value.edition)" != "OSS" ]]; do sleep 5; done'

# print the version using the API.
wget -qO- http://localhost:8081/service/extdirect/poll/rapture_State_get | jq --raw-output .data.data.uiSettings.value.title
wget -qO- http://localhost:8081/service/extdirect/poll/rapture_State_get | jq .data.data.status.value

# configure nexus with the groovy script.
bash /vagrant/provision/execute-provision.groovy-script.sh
