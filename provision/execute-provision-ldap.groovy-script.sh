#!/bin/bash
set -eux

. /vagrant/provision/nexus-groovy.sh

# run the provision script.
response=$(nexus-groovy provision-ldap)
echo "$response" | jq '.result | fromjson'
