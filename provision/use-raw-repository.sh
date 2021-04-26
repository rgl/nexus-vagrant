#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

mkdir -p tmp/use-raw-repository && cd tmp/use-raw-repository

#
# test the raw repository.

apt-get install -y curl

# upload.
# see https://help.sonatype.com/display/NXRM3/Raw+Repositories+and+Maven+Sites#RawRepositoriesandMavenSites-UploadingFilestoHostedRawRepositories
expected='this is an adhoc package'
echo "$expected" >package-1.0.0.txt
curl --silent --user 'alice.doe:password' --upload-file package-1.0.0.txt https://$nexus_domain/repository/adhoc-package/package-1.0.0.txt

# download.
actual=$(curl --silent https://$nexus_domain/repository/adhoc-package/package-1.0.0.txt)
[ "$actual" = "$expected" ] || (echo 'upload adhoc package test failed' && false)
