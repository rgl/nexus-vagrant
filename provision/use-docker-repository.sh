#!/bin/bash
set -eux

nexus_domain=$(hostname --fqdn)
docker_group_registry_host="$nexus_domain:5001"
docker_hosted_registry_host="$nexus_domain:5003"
registry_username='alice.doe'
registry_password='password'

# login into the registry.
echo "logging in the registry $docker_group_registry_host..."
docker login $docker_group_registry_host --username "$registry_username" --password-stdin <<EOF
$registry_password
EOF
echo "logging in the registry $docker_hosted_registry_host..."
docker login $docker_hosted_registry_host --username "$registry_username" --password-stdin <<EOF
$registry_password
EOF

mkdir -p tmp/use-docker-repository && cd tmp/use-docker-repository

#
# test the docker repository.

cat >main.go <<'EOF'
package main

import (
    "fmt"
    "flag"
    "log"
    "net/http"
)

func main() {
    log.SetFlags(0)

    var listenAddress = flag.String("listen", ":8000", "Listen address.")

    flag.Parse()

    if flag.NArg() != 0 {
        flag.Usage()
        log.Fatalf("\nERROR You MUST NOT pass any positional arguments")
    }

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "text/plain")
        fmt.Printf("%s %s%s\n", r.Method, r.Host, r.URL)
        fmt.Fprintf(w, "%s %s%s\n", r.Method, r.Host, r.URL)
    })

    fmt.Printf("Listening at http://%s\n", *listenAddress)

    err := http.ListenAndServe(*listenAddress, nil)
    if err != nil {
        log.Fatalf("Failed to ListenAndServe: %v", err)
    }
}
EOF
cat >go.mod <<'EOF'
module example.com/go-hello

go 1.16
EOF
cat >Dockerfile <<'EOF'
FROM golang:1.16.0-buster as builder
WORKDIR /app
COPY go.* main.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s"

# NB we use the buster-slim (instead of scratch) image so we
#    can enter the container to execute bash etc.
FROM debian:buster-slim
COPY --from=builder /app/go-hello .
WORKDIR /
EXPOSE 8000
ENTRYPOINT ["/go-hello"]
EOF

# build the image.
docker build -t go-hello:1.0.0 .
docker image ls go-hello:1.0.0

# push the image to the docker-hosted registry.
docker tag go-hello:1.0.0 $docker_hosted_registry_host/go-hello:1.0.0
docker push $docker_hosted_registry_host/go-hello:1.0.0

# show the repository (image) details directly from the docker-hosted registry.
# see https://docs.docker.com/registry/spec/api/
# see https://docs.docker.com/registry/spec/manifest-v2-2/
wget -qO- --user "$registry_username" --password "$registry_password" \
    "https://$docker_hosted_registry_host/v2/go-hello/tags/list" | jq .
manifest=$(wget -qO- --user "$registry_username" --password "$registry_password" \
    '--header=Accept: application/vnd.docker.distribution.manifest.v2+json' \
    "https://$docker_hosted_registry_host/v2/go-hello/manifests/1.0.0")
config_digest=$(echo "$manifest" | jq -r .config.digest)
echo "$manifest" | jq .
wget -qO- --user "$registry_username" --password "$registry_password" \
    "https://$docker_hosted_registry_host/v2/go-hello/blobs/$config_digest" | jq .

# remove it from local cache.
docker image remove go-hello:1.0.0
docker image remove $docker_hosted_registry_host/go-hello:1.0.0

# pull it from the docker-group registry.
docker pull $docker_group_registry_host/go-hello:1.0.0
