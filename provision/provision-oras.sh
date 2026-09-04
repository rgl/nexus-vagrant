#!/bin/bash
set -euxo pipefail

# see https://github.com/oras-project/oras/releases
# renovate: datasource=github-releases depName=oras-project/oras
version='1.3.4'

# download and install.
url="https://github.com/oras-project/oras/releases/download/v${version}/oras_${version}_linux_amd64.tar.gz"
t="$(mktemp -q -d --suffix=.oras)"
wget -qO- "$url" | tar xzf - -C "$t" --strip-components=0 oras
install -m 755 "$t/oras" /usr/local/bin/oras
rm -rf "$t"
