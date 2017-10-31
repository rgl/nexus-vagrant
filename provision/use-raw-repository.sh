#!/bin/bash
set -eux

mkdir -p tmp/use-raw-repository && cd tmp/use-raw-repository

#
# test the raw repository.

apt-get install -y curl

# upload.
# see https://help.sonatype.com/display/NXRM3/Raw+Repositories+and+Maven+Sites#RawRepositoriesandMavenSites-UploadingFilestoHostedRawRepositories
expected='this is an adhoc package'
echo "$expected" >package-1.0.0.txt
curl --silent --user 'alice.doe:password' --upload-file package-1.0.0.txt http://localhost:8081/repository/adhoc-package/package-1.0.0.txt

# download.
actual=$(curl --silent http://localhost:8081/repository/adhoc-package/package-1.0.0.txt)
[ "$actual" = "$expected" ] || (echo 'upload adhoc package test failed' && false)
