#!/bin/bash
set -eux

nexus_domain=$(hostname --fqdn)

. /vagrant/provision/nexus-groovy.sh

mkdir -p tmp/use-nuget-repository && cd tmp/use-nuget-repository

#
# test the NuGet repository.
# see https://help.sonatype.com/display/NXRM3/.NET+Package+Repositories+with+NuGet

if ! which mono; then
  sudo apt-get install -y mono-complete
fi
if [[ ! -f /tmp/nuget.exe ]]; then
  # NB ubuntu 16.04 mono cannot run nuget.exe versions above 4.5.1.
  #    see https://github.com/NuGet/Home/issues/6790
  wget -qO/tmp/nuget.exe https://dist.nuget.org/win-x86-commandline/v4.5.1/nuget.exe
fi

function nuget {
  mono /tmp/nuget.exe $*
}

nuget | grep -i version:

nuget_source_url=https://$nexus_domain/repository/nuget-group/
nuget_source_push_url=https://$nexus_domain/repository/nuget-hosted/
nuget_source_push_api_key=$(nexus-groovy get-jenkins-nuget-api-key | jq -r '.result | fromjson | .apiKey')
echo -n $nuget_source_push_api_key >/vagrant/shared/jenkins-nuget-api-key

# test installing a package from the public NuGet repository.
nuget install MsgPack -Source $nuget_source_url

# test publishing a package.
cat >example-hello-world.nuspec <<'EOF'
<package>
  <metadata>
    <id>example-hello-world</id>
    <version>1.0.0</version>
    <authors>Alice Doe</authors>
    <owners>Bob Doe</owners>
    <licenseUrl>http://choosealicense.com/licenses/mit/</licenseUrl>
    <projectUrl>http://example.com</projectUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>Example Package Description</description>
    <releaseNotes>Hello World.</releaseNotes>
    <copyright>Copyleft Alice Doe</copyright>
    <tags>hello world</tags>
  </metadata>
  <files>
    <file src="MESSAGE.md" target="content" />
  </files> 
</package>
EOF
cat >MESSAGE.md <<'EOF'
# Hello World

Hey Ho Let's Go!
EOF
nuget pack example-hello-world.nuspec
nuget push example-hello-world.1.0.0.nupkg -Source $nuget_source_push_url -ApiKey $nuget_source_push_api_key
# test installing it back.
rm -rf test && mkdir test && pushd test 
nuget install example-hello-world -Source $nuget_source_url
if [[ ! -f example-hello-world.1.0.0/content/MESSAGE.md ]]; then
  echo 'the package did not install as expected'
  exit 1
fi
popd
