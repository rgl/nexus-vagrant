#!/bin/bash
set -eux

nexus_domain=$(hostname --fqdn)

. /vagrant/provision/nexus-groovy.sh

mkdir -p tmp/use-nuget-repository && cd tmp/use-nuget-repository

#
# test the NuGet repository.
# see https://help.sonatype.com/display/NXRM3/.NET+Package+Repositories+with+NuGet

if ! which mono; then
  # install the latest stable mono.
  # NB this is needed to run the latest nuget.exe.
  # see https://www.mono-project.com/download/stable/#download-lin-ubuntu
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
  apt-get install -y apt-transport-https
  echo "deb https://download.mono-project.com/repo/ubuntu stable-$(lsb_release -sc) main" >/etc/apt/sources.list.d/mono-official-stable.list
  apt-get update
  apt-get install -y mono-complete
fi
if [[ ! -f /tmp/nuget.exe ]]; then
  wget -qO/tmp/nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
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
