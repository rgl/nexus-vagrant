#!/bin/bash
set -eux

nexus_domain=$(hostname --fqdn)

# use the local nexus user database.
config_authentication='nexus'
# OR use LDAP.
# NB this assumes you are running the Active Directory from https://github.com/rgl/windows-domain-controller-vagrant.
#config_authentication='ldap'


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
# see https://help.sonatype.com/display/NXRM3
nexus_tarball=nexus-3.6.1-02-unix.tar.gz
nexus_download_url=https://sonatype-download.global.ssl.fastly.net/nexus/3/$nexus_tarball
nexus_download_sha1=da2ea7cfe282b9372f818c011c28c8c41246ae24
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


# trust the LDAP server certificate for user authentication (when enabled).
# NB this assumes you are running the Active Directory from https://github.com/rgl/windows-domain-controller-vagrant.
if [ "$config_authentication" = 'ldap' ]; then
echo '192.168.56.2 dc.example.com' >>/etc/hosts
openssl x509 -inform der -in /vagrant/shared/ExampleEnterpriseRootCA.der -out /usr/local/share/ca-certificates/ExampleEnterpriseRootCA.crt
update-ca-certificates -v
fi


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
Restart=on-abort
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
systemctl enable nexus
systemctl start nexus

# install tools.
apt-get install -y --no-install-recommends httpie
apt-get install -y --no-install-recommends jq

# wait for nexus to come up.
bash -c "while [[ \"\$(wget -qO- https://$nexus_domain/service/extdirect/poll/rapture_State_get | jq -r .data.data.status.value.edition)\" != 'OSS' ]]; do sleep 5; done"

# print the version using the API.
wget -qO- https://$nexus_domain/service/extdirect/poll/rapture_State_get | jq --raw-output .data.data.uiSettings.value.title
wget -qO- https://$nexus_domain/service/extdirect/poll/rapture_State_get | jq .data.data.status.value

# configure nexus with the groovy script.
bash /vagrant/provision/execute-provision.groovy-script.sh

# configure nexus ldap with a groovy script.
if [ "$config_authentication" = 'ldap' ]; then
    bash /vagrant/provision/execute-provision-ldap.groovy-script.sh
fi
