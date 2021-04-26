#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

. /vagrant/provision/nexus-groovy.sh

# run the provision script.
response=$(nexus-groovy provision-ldap)
echo "$response" | jq '.result | fromjson'
