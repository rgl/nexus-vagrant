#!/bin/bash
# here be dragons... see http://fvue.nl/wiki/Bash:_Error_handling
set -eux

config_fqdn=$(hostname --fqdn)
config_domain=$(hostname --domain)

echo "127.0.0.1 $config_fqdn" >>/etc/hosts


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
# see https://help.sonatype.com/display/NXRM3/Installation#Installation-RunningBehindaReverseProxy
apt-get install -y --no-install-recommends nginx
rm -f /etc/nginx/sites-enabled/default
cat >/etc/nginx/sites-available/$config_fqdn.conf <<EOF
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
