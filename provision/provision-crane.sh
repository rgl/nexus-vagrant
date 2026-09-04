#!/bin/bash
set -euxo pipefail

# see https://github.com/google/go-containerregistry/releases
# renovate: datasource=github-releases depName=google/go-containerregistry
version='0.22.1'

# download and install.
url="https://github.com/google/go-containerregistry/releases/download/v$version/go-containerregistry_Linux_x86_64.tar.gz"
t="$(mktemp -q -d --suffix=.crane)"
wget -qO- "$url" | tar xzf - -C "$t" --strip-components=0 crane
install -m 755 "$t/crane" /usr/local/bin/crane
rm -rf "$t"
