#!/bin/bash
set -eux

. /vagrant/provision/nexus-groovy.sh

# list existing scripts.
#http -a "$admin_username:$admin_password" http://localhost:8081/service/siesta/rest/v1/script | jq .

# run the provision script.
response=$(nexus-groovy provision)
echo "$response" | jq '.result | fromjson'
