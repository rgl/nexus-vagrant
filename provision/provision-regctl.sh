#!/bin/bash
set -euxo pipefail

# see https://github.com/regclient/regclient/releases
# renovate: datasource=github-releases depName=regclient/regclient
version='0.11.6'

# download and install.
name='regctl'
url="https://github.com/regclient/regclient/releases/download/v$version/$name-linux-amd64"
t="$(mktemp -q -d --suffix=.regclient)"
wget "-qO$t/$name" "$url"
install -m 755 "$t/$name" "/usr/local/bin/$name"
rm -rf "$t"
