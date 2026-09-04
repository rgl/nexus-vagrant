#!/bin/bash
set -euxo pipefail

# see https://github.com/anchore/syft/releases
# renovate: datasource=github-releases depName=anchore/syft
version='1.51.1'

# download and install.
syft_url="https://github.com/anchore/syft/releases/download/v${version}/syft_${version}_linux_amd64.tar.gz"
t="$(mktemp -q -d --suffix=.syft)"
wget -qO- "$syft_url" | tar xzf - -C "$t" syft
install -m 755 "$t/syft" /usr/local/bin/
rm -rf "$t"
