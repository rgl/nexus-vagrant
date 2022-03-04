#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

mkdir -p tmp/use-npm-repository && cd tmp/use-npm-repository

#
# test the npm repositories.
# see https://help.sonatype.com/display/NXRM3/Node+Packaged+Modules+and+npm+Registries
# see https://docs.npmjs.com/private-modules/ci-server-config
# see https://docs.npmjs.com/cli/adduser

# install node LTS.
# see https://github.com/nodesource/distributions#debinstall
curl -sL --fail --show-error https://deb.nodesource.com/setup_16.x | bash
apt-get install -y nodejs
node --version
npm --version

# configure npm to trust our system trusted CAs.
# NB never turn off ssl verification with npm config set strict-ssl false
npm config set cafile /etc/ssl/certs/ca-certificates.crt

#
# configure npm to use the npm-group repository.

npm config set registry https://$nexus_domain/repository/npm-group/

# install a package that indirectly uses the npmjs.org-proxy repository.
mkdir hello-world-npm
pushd hello-world-npm
cat >package.json <<'EOF'
{
  "name": "hello-world",
  "description": "the classic hello world",
  "version": "1.0.0",
  "license": "MIT",
  "main": "hello-world.js",
  "repository": {
    "type": "git",
    "url": "https://git.example.com/hello-world.git"
  },
  "dependencies": {}
}
EOF
cat >hello-world.js <<'EOF'
const leftPad = require('left-pad')
console.log(leftPad('hello world', 40))
EOF
npm install --save left-pad
node hello-world.js

#
# publish a package to the npm-hosted repository.

# login.
export NPM_USER=alice.doe
export NPM_PASS=password
export NPM_EMAIL=alice.doe@example.com
export NPM_REGISTRY=https://$nexus_domain/repository/npm-hosted/
npm install npm-registry-client@8.6.0
npm_auth_token=$(NODE_PATH=$PWD/node_modules node --use-openssl-ca /vagrant/provision/npm-login.js 2>/dev/null)
npm set //$nexus_domain/repository/npm-hosted/:_authToken $npm_auth_token

# publish.
# NB instead of using the token from the npm configuration you can
#    export the NPM_TOKEN environment variable.
npm publish --registry=$NPM_REGISTRY
popd

# use the published package.
mkdir use-hello-world-npm
pushd use-hello-world-npm
cat >package.json <<'EOF'
{
  "name": "use-hello-world",
  "description": "use the classic hello world",
  "version": "1.0.0",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://git.example.com/use-hello-world.git"
  },
  "dependencies": {}
}
EOF
npm install hello-world
node node_modules/hello-world/hello-world.js
popd
