param(
    [string]$nexusDomain = 'nexus.example.com'
)

function external([string]$cmd, [string[]]$arguments) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        &$cmd @arguments
        if ($LASTEXITCODE) {
            throw "$cmd failed with exit code $LASTEXITCODE"
        }
    } finally {
        $ErrorActionPreference = $eap
    }
}
function node { external node.exe $Args }
function npm { external npm.cmd $Args }

Set-Location $env:USERPROFILE
mkdir tmp | Out-Null
mkdir tmp/use-npm-repository | Out-Null
Set-Location tmp/use-npm-repository

#
# test the npm repositories.
# see https://help.sonatype.com/display/NXRM3/Node+Packaged+Modules+and+npm+Registries
# see https://docs.npmjs.com/private-modules/ci-server-config
# see https://docs.npmjs.com/cli/adduser

# install node LTS.
# see https://community.chocolatey.org/packages/nodejs-lts
choco install -y nodejs-lts --version 22.18.0
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
Update-SessionEnvironment
node --version
npm --version

# configure npm to trust our system trusted CAs.
# NB never turn off ssl verification with npm config set strict-ssl false
c:\vagrant\provision\windows\export-windows-ca-certificates.ps1
npm config set cafile c:/ProgramData/ca-certificates.crt

#
# configure npm to use the npm-group repository.

npm config set registry https://$nexusDomain/repository/npm-group/

# install a package that indirectly uses the npmjs.org-proxy repository.
mkdir hello-world-win-npm | Out-Null
Push-Location hello-world-win-npm
Set-Content `
    -Encoding Ascii `
    package.json `
    @'
{
  "name": "hello-world-win",
  "description": "the classic hello world",
  "version": "1.0.0",
  "license": "MIT",
  "main": "hello-world-win.js",
  "repository": {
    "type": "git",
    "url": "https://git.example.com/hello-world-win.git"
  },
  "dependencies": {}
}
'@
Set-Content `
    -Encoding Ascii `
    hello-world-win.js `
    @'
const leftPad = require('left-pad')
console.log(leftPad('hello world', 40))
'@
npm install --save left-pad
node hello-world-win.js

#
# publish a package to the npm-hosted repository.

# login.
$env:NPM_USER='alice.doe'
$env:NPM_PASS='password'
$env:NPM_EMAIL='alice.doe@example.com'
$env:NPM_REGISTRY="https://$nexusDomain/repository/npm-hosted/"
npm install npm-registry-client@8.6.0
$env:NODE_PATH="$PWD/node_modules"
$env:NODE_EXTRA_CA_CERTS='C:\ProgramData\ca-certificates.crt'
$npmAuthToken = node --use-openssl-ca /vagrant/provision/npm-login.js 2>$null
npm set "//$nexusDomain/repository/npm-hosted/:_authToken" $npmAuthToken

# publish.
# NB instead of using the token from the npm configuration you can
#    set the NPM_TOKEN environment variable.
npm publish --registry=$env:NPM_REGISTRY
Pop-Location

# use the published package.
mkdir use-hello-world-win-npm | Out-Null
Push-Location use-hello-world-win-npm
Set-Content `
    -Encoding Ascii `
    hello-world-win.js `
    @'
{
  "name": "use-hello-world-win",
  "description": "use the classic hello world",
  "version": "1.0.0",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://git.example.com/use-hello-world-win.git"
  },
  "dependencies": {}
}
'@
npm install hello-world-win
node node_modules/hello-world-win/hello-world-win.js
Pop-Location
