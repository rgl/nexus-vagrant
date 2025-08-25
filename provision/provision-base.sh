#!/bin/bash
# here be dragons... see http://fvue.nl/wiki/Bash:_Error_handling
set -euxo pipefail

config_fqdn=$(hostname --fqdn)
config_domain=$(hostname --domain)

echo "127.0.0.1 $config_fqdn" >>/etc/hosts


# enable systemd-journald persistent logs.
sed -i -E 's,^#?(Storage=).*,\1persistent,' /etc/systemd/journald.conf
systemctl restart systemd-journald


# disable IPv6.
cat >/etc/sysctl.d/98-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
systemctl restart procps
sed -i -E 's,(GRUB_CMDLINE_LINUX=.+)",\1 ipv6.disable=1",' /etc/default/grub
update-grub2


# update the package cache.
apt-get -y update

# install a EGD (Entropy Gathering Daemon).
# NB the host should have an EGD and expose/virtualize it to the guest.
#    on libvirt there's virtio-rng which will read from the host /dev/random device
#    so your host should have a TRNG (True RaNdom Generator) with rng-tools
#    reading from it and feeding it into /dev/random or have the haveged
#    daemon running.
# see https://wiki.qemu.org/Features/VirtIORNG
# see https://wiki.archlinux.org/index.php/Rng-tools
# see https://www.kernel.org/doc/Documentation/hw_random.txt
# see https://hackaday.com/2017/11/02/what-is-entropy-and-how-do-i-get-more-of-it/
# see cat /sys/devices/virtual/misc/hw_random/rng_current
# see cat /proc/sys/kernel/random/entropy_avail
# see rngtest -c 1000 </dev/hwrng
# see rngtest -c 1000 </dev/random
# see rngtest -c 1000 </dev/urandom
apt-get install -y rng-tools

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
openssl x509 \
    -in $config_fqdn-crt.pem \
    -outform der \
    -out $config_fqdn-crt.der
openssl x509 \
    -noout \
    -text \
    -in $config_fqdn-crt.pem
# copy the certificate to a place where it can be used by other machines.
mkdir -p /vagrant/shared
cp $config_fqdn-crt.* /vagrant/shared
# configure our system to trust the certificate.
cp $config_fqdn-crt.pem /usr/local/share/ca-certificates/$config_fqdn.crt
update-ca-certificates -v
popd


# install and configure nginx to proxy to nexus.
# see https://help.sonatype.com/repomanager3/planning-your-implementation/run-behind-a-reverse-proxy
apt-get install -y --no-install-recommends nginx
wget -qO /etc/ssl/certs/dhparam.pem https://ssl-config.mozilla.org/ffdhe2048.txt
sed -i -E 's/^(\s*)((ssl_protocols|ssl_ciphers|ssl_prefer_server_ciphers)\s)/\1# \2/' /etc/nginx/nginx.conf
cat >/etc/nginx/conf.d/local.conf <<EOF
# NB this is based on the mozilla intermediate configuration.
# see https://ssl-config.mozilla.org/#server=nginx&version=1.18.0&config=intermediate&openssl=3.0.2&guideline=5.7
# see https://packages.ubuntu.com/jammy/nginx
# see https://packages.ubuntu.com/jammy/openssl
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m; # about 40000 sessions.
ssl_session_timeout 1d;
ssl_session_tickets on;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
# NB our example ca does not support stapling, so this is commented.
#ssl_stapling on;
#ssl_stapling_verify on;
#ssl_trusted_certificate /etc/ssl/certs/jenkins-ca.pem;
#resolver 127.0.0.53 valid=30s;
#resolver_timeout 5s;
EOF
rm -f /etc/nginx/sites-enabled/default
cat >/etc/nginx/sites-available/$config_fqdn.conf <<EOF
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

  tcp_nodelay on;
  client_max_body_size 1G;
  proxy_send_timeout 120;
  proxy_read_timeout 300;
  proxy_buffering off;

  location /h2-console/ {
    proxy_http_version 1.1;
    proxy_pass http://localhost:8082/;
    proxy_redirect http://localhost:8082/ /h2-console/;
  }

  location / {
    root /opt/nexus/public;
    try_files \$uri @nexus;
  }

  location @nexus {
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass http://127.0.0.1:8081;
  }
}

# docker-group repository.
server {
  listen 5001 ssl http2;
  server_name $config_fqdn;
  access_log /var/log/nginx/$config_fqdn-docker-group.access.log;

  ssl_certificate /etc/ssl/private/$config_fqdn-crt.pem;
  ssl_certificate_key /etc/ssl/private/$config_fqdn-keypair.pem;

  tcp_nodelay on;
  client_max_body_size 10G;
  proxy_send_timeout 120;
  proxy_read_timeout 300;
  proxy_buffering off;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header Host \$host;
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

  location / {
    proxy_pass http://127.0.0.1:6001;
  }
}

# docker-hub-proxy repository.
server {
  listen 5002 ssl http2;
  server_name $config_fqdn;
  access_log /var/log/nginx/$config_fqdn-docker-hub-proxy.access.log;

  ssl_certificate /etc/ssl/private/$config_fqdn-crt.pem;
  ssl_certificate_key /etc/ssl/private/$config_fqdn-keypair.pem;

  tcp_nodelay on;
  client_max_body_size 10G;
  proxy_send_timeout 120;
  proxy_read_timeout 300;
  proxy_buffering off;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header Host \$host;
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

  location / {
    proxy_pass http://127.0.0.1:6002;
  }
}

# docker-hosted repository.
server {
  listen 5003 ssl http2;
  server_name $config_fqdn;
  access_log /var/log/nginx/$config_fqdn-docker-hosted.access.log;

  ssl_certificate /etc/ssl/private/$config_fqdn-crt.pem;
  ssl_certificate_key /etc/ssl/private/$config_fqdn-keypair.pem;

  tcp_nodelay on;
  client_max_body_size 10G;
  proxy_send_timeout 120;
  proxy_read_timeout 300;
  proxy_buffering off;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header Host \$host;
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

  location / {
    proxy_pass http://127.0.0.1:6003;
  }
}
EOF
ln -s ../sites-available/$config_fqdn.conf /etc/nginx/sites-enabled/
systemctl restart nginx
