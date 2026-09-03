#!/bin/bash
set -euxo pipefail

nexus_domain="$(hostname --fqdn)"
registry_domain="$nexus_domain"
registry_username='alice.doe'
registry_password='password'
oci_hosted_repository_name='oci-hosted'
oci_hosted_repository_host="$registry_domain/$oci_hosted_repository_name"
oci_hosted_repository_api_url="https://$registry_domain/v2/$oci_hosted_repository_name"

# login into the registry.
echo "logging in the registry $registry_domain..."
docker login "$registry_domain" --username "$registry_username" --password-stdin <<EOF
$registry_password
EOF

mkdir -p tmp/use-oci-repository && cd tmp/use-oci-repository

#
# test the oci repository.

# see https://github.com/golang/go/tags
# renovate: datasource=github-tags depName=golang/go extractVersion=go(?<version>.+)
go_version='1.27.1'

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
cat >go.mod <<EOF
module example.com/go-hello-oci

go $go_version
EOF
cat >Dockerfile <<EOF
FROM golang:$go_version-trixie AS builder
WORKDIR /app
COPY go.* main.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s"

# NB we use the trixie-slim (instead of scratch) image so we
#    can enter the container to execute bash etc.
FROM debian:trixie-slim
COPY --from=builder /app/go-hello-oci .
WORKDIR /
EXPOSE 8000
ENTRYPOINT ["/go-hello-oci"]
EOF

# build the image.
docker build -t go-hello-oci:1.0.0 .
docker image ls go-hello-oci:1.0.0

# push the image to the oci-hosted repository.
docker tag go-hello-oci:1.0.0 "$oci_hosted_repository_host/go-hello-oci:1.0.0"
docker push "$oci_hosted_repository_host/go-hello-oci:1.0.0"

# show the repository (image) details directly from the oci-hosted repository.
# see https://specs.opencontainers.org/distribution-spec/?v=v1.1.1
# see https://github.com/opencontainers/distribution-spec
wget -qO- --user "$registry_username" --password "$registry_password" \
    "$oci_hosted_repository_api_url/go-hello-oci/tags/list" | jq .
oci_image_index="$(wget -qO- --user "$registry_username" --password "$registry_password" \
    '--header=Accept: application/vnd.oci.image.index.v1+json' \
    "$oci_hosted_repository_api_url/go-hello-oci/manifests/1.0.0")"
echo "$oci_image_index" | jq .
oci_image_manifest_digest="$(echo "$oci_image_index" | jq -r .manifests[0].digest)"
oci_image_manifest="$(wget -qO- --user "$registry_username" --password "$registry_password" \
    '--header=Accept: application/vnd.oci.image.manifest.v1+json' \
    "$oci_hosted_repository_api_url/go-hello-oci/manifests/$oci_image_manifest_digest")"
echo "$oci_image_manifest" | jq .
oci_image_config_digest="$(echo "$oci_image_manifest" | jq -r .config.digest)"
config_digest="$(echo "$oci_image_manifest" | jq -r .config.digest)"
wget -qO- --user "$registry_username" --password "$registry_password" \
    "$oci_hosted_repository_api_url/go-hello-oci/blobs/$oci_image_config_digest" | jq .

# remove it from local cache.
docker image remove go-hello-oci:1.0.0
docker image remove "$oci_hosted_repository_host/go-hello-oci:1.0.0"

# pull it from the oci-hosted repository.
docker pull "$oci_hosted_repository_host/go-hello-oci:1.0.0"
