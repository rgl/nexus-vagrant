#!/bin/bash
# here be dragons... see http://fvue.nl/wiki/Bash:_Error_handling
set -eux

config_fqdn=$(hostname --fqdn)
config_domain=$(hostname --domain)

echo "127.0.0.1 $config_fqdn" >>/etc/hosts


# update the package cache.
apt-get -y update


# vim.
apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
autocmd BufNewFile,BufRead Vagrantfile set ft=ruby
EOF


# create a self-signed certificate.
pushd /etc/ssl/private
openssl genrsa \
    -out $config_fqdn-keypair.pem \
    2048 \
    2>/dev/null
chmod 400 $config_fqdn-keypair.pem
openssl req -new \
    -sha256 \
    -subj "/CN=$config_fqdn" \
    -key $config_fqdn-keypair.pem \
    -out $config_fqdn-csr.pem
openssl x509 -req -sha256 \
    -signkey $config_fqdn-keypair.pem \
    -extensions a \
    -extfile <(echo "[a]
        subjectAltName=DNS:$config_fqdn
        extendedKeyUsage=serverAuth
        ") \
    -days 365 \
    -in  $config_fqdn-csr.pem \
    -out $config_fqdn-crt.pem
popd


# install and configure nginx to proxy to nexus.
# see https://books.sonatype.com/nexus-book/3.0/reference/install.html#reverse-proxy
apt-get install -y --no-install-recommends nginx
rm -f /etc/nginx/sites-enabled/default
cat<<EOF>/etc/nginx/sites-available/$config_fqdn.conf
ssl_session_cache shared:SSL:4m;
ssl_session_timeout 6h;
#ssl_stapling on;
#ssl_stapling_verify on;

server {
  listen 80;
  server_name _;
  return 301 https://$config_fqdn\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name $config_fqdn;
  access_log /var/log/nginx/$config_fqdn.access.log;

  ssl_certificate /etc/ssl/private/$config_fqdn-crt.pem;
  ssl_certificate_key /etc/ssl/private/$config_fqdn-keypair.pem;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  # see https://github.com/cloudflare/sslconfig/blob/master/conf
  # see https://blog.cloudflare.com/it-takes-two-to-chacha-poly/
  # see https://blog.cloudflare.com/do-the-chacha-better-mobile-performance-with-cryptography/
  # NB even though we have CHACHA20 here, the OpenSSL library that ships with Ubuntu 16.04 does not have it. so this is a nop. no problema.
  ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!aNULL:!MD5;

  tcp_nodelay on;
  client_max_body_size 1G;
  proxy_send_timeout 120;
  proxy_read_timeout 300;
  proxy_buffering off;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header Host \$host;
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

  location / {
    root /opt/nexus/public;
    try_files \$uri @nexus;
  }

  location @nexus {
    proxy_pass http://127.0.0.1:8081;
  }
}
EOF
ln -s ../sites-available/$config_fqdn.conf /etc/nginx/sites-enabled/
systemctl restart nginx


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
# see https://books.sonatype.com/nexus-book/3.0/reference/index.html
nexus_tarball=nexus-3.1.0-04-unix.tar.gz
nexus_download_url=https://sonatype-download.global.ssl.fastly.net/nexus/3/$nexus_tarball
nexus_download_sha1=e42053ba8ab33b3b4f79f7e50dbac2ffe6ca3b6e
wget -q $nexus_download_url
if [ "$(sha1sum $nexus_tarball | awk '{print $1}')" != "$nexus_download_sha1" ]; then
    echo "downloaded $nexus_download_url failed the checksum verification"
    exit 1
fi
tar xf $nexus_tarball --strip-components 1
rm $nexus_tarball
chmod 700 nexus3
chown -R nexus:nexus nexus3
chmod 700 etc
chown -R nexus:nexus etc # for some reason karaf changes files inside this directory. TODO see why.
install -d -o nexus -g nexus -m 700 .java # java preferences are saved here (the default java.util.prefs.userRoot preference).
cp -p etc/{nexus-default.properties,nexus.properties}
sed -i -E 's,(application-host=).+,\1127.0.0.1,g' etc/nexus.properties
sed -i -E 's,nexus-pro-,nexus-oss-,g' etc/nexus.properties
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

# clean packages.
apt-get -y autoremove
apt-get -y clean
