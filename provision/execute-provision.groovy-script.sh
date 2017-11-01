#!/bin/bash
set -eux

nexus_domain=$(hostname --fqdn)

. /vagrant/provision/nexus-groovy.sh

# list existing scripts.
#http -a "$admin_username:$admin_password" https://$nexus_domain/service/siesta/rest/v1/script | jq .

# run the provision script.
response=$(nexus-groovy provision)
echo "$response" | jq '.result | fromjson'
