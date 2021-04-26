#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

. /vagrant/provision/nexus-groovy.sh

# NB this is the default nexus password, which will be changed to
#    'admin' by the provision.groovy script that we run bellow.
admin_password='admin123'

# list existing scripts.
#http -a "$admin_username:$admin_password" https://$nexus_domain/service/rest/v1/script | jq .

# run the provision script.
response=$(nexus-groovy provision)
echo "$response" | jq '.result | fromjson'
