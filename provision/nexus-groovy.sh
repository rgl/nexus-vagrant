#!/bin/bash
set -eux

admin_username=${admin_username:-admin}
admin_password=${admin_password:-$(cat /opt/nexus/sonatype-work/nexus3/admin.password)}

# see https://help.sonatype.com/display/NXRM3/REST+and+Integration+API
# see https://nexus.example.com/swagger-ui/
function nexus-groovy {
    local source_filename="/vagrant/provision/provision-nexus/src/main/groovy/$1.groovy"

    local delete_result=$(http \
        -a "$admin_username:$admin_password" \
        --ignore-stdin \
        DELETE https://$nexus_domain/service/rest/v1/script/provision.groovy)   

    local create_result=$(http \
        -a "$admin_username:$admin_password" \
        --ignore-stdin \
        --check-status \
        POST https://$nexus_domain/service/rest/v1/script \
        name=provision.groovy \
        type=groovy \
        "content=@$source_filename")

    http \
        -a "$admin_username:$admin_password" \
        --ignore-stdin \
        --check-status \
        POST https://$nexus_domain/service/rest/v1/script/provision.groovy/run \
        Content-Type:text/plain
}
