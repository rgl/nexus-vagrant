#!/bin/bash
set -euxo pipefail

. /vagrant/provision/nexus-groovy.sh

config_fqdn=$(hostname --fqdn)

# show the installation summary.
cat <<EOF
nexus is running at:

   https://$config_fqdn

use the admin/$admin_password credentials to login.

the api browser at:

   https://$config_fqdn/#admin/system/api

the logs are at:

   /opt/nexus/sonatype-work/nexus3/log/
EOF
