#!/bin/bash
set -eux

admin_username=${admin_username:-admin}
admin_password=${admin_password:-admin123}

# see https://books.sonatype.com/nexus-book/3.4/reference/scripting.html
function nexus-groovy {
    local source_filename="/vagrant/provision/provision-nexus/src/main/groovy/$1.groovy"

    local delete_result=$(http \
        -a "$admin_username:$admin_password" \
        --ignore-stdin \
        DELETE http://localhost:8081/service/siesta/rest/v1/script/provision.groovy)   

    local create_result=$(http \
        -a "$admin_username:$admin_password" \
        --ignore-stdin \
        --check-status \
        POST http://localhost:8081/service/siesta/rest/v1/script \
        name=provision.groovy \
        type=groovy \
        "content=@$source_filename")

    http \
        -a "$admin_username:$admin_password" \
        --ignore-stdin \
        --check-status \
        POST http://localhost:8081/service/siesta/rest/v1/script/provision.groovy/run \
        Content-Type:text/plain
}
