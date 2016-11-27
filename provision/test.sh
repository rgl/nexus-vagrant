#!/bin/bash
set -eux

. /vagrant/provision/nexus-groovy.sh

mkdir -p tmp && cd tmp

#
# test the NuGet repository.
# see https://books.sonatype.com/nexus-book/3.0/reference/nuget.html

if ! which mono; then
  sudo apt-get install -y mono-complete
fi
if [[ ! -f /tmp/nuget.exe ]]; then
  wget -qO/tmp/nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
fi

function nuget {
  mono /tmp/nuget.exe $*
}

nuget_source_url=http://localhost:8081/repository/nuget-group/
nuget_source_push_url=http://localhost:8081/repository/nuget-hosted/
nuget_source_push_api_key=$(nexus-groovy get-jenkins-nuget-api-key | jq -r '.result | fromjson | .apiKey')

# test installing a package from the public NuGet repository.
nuget install MsgPack -Source $nuget_source_url

# test publishing a package.
cat <<'EOF' >example-hello-world.nuspec
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
cat <<'EOF' >MESSAGE.md
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


#
# test the maven repository.

# install maven and the java development kit.
sudo apt-get install -y maven
sudo apt-get install -y default-jdk
sudo apt-get install -y xmlstarlet

# setup the user maven configuration to use nexus as a mirror the
# official maven repository.
# see https://books.sonatype.com/nexus-book/3.0/reference/maven.html
# see https://maven.apache.org/guides/mini/guide-mirror-settings.html
mkdir -p ~/.m2
cat <<'EOF' >~/.m2/settings.xml
<settings>
  <servers>
    <server>
      <id>nexus</id>
      <username>alice.doe</username>
      <password>password</password>
    </server>
  </servers>
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>central</mirrorOf>
      <url>http://localhost:8081/repository/maven-public/</url>
    </mirror>
  </mirrors>
  <profiles>
    <profile>
      <id>nexus</id>
      <repositories>
        <repository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
     <pluginRepositories>
        <pluginRepository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
EOF

# test our nexus repository by creating an hello world project, which
# will pull from our nexus repository.
mvn \
  archetype:generate \
  -DgroupId=com.example.helloworld \
  -DartifactId=example-helloworld \
  -DarchetypeArtifactId=maven-archetype-quickstart \
  -DinteractiveMode=false

# test publishing a package.
pushd example-helloworld
# add the nexus repository to pom.xml.
xmlstarlet ed --inplace -N pom=http://maven.apache.org/POM/4.0.0 \
  --subnode '/pom:project' \
  --type elem \
  --name distributionManagement \
  --value '@@repositories@@' \
  pom.xml
python -c '
xml = open("pom.xml").read().replace("@@repositories@@", """
    <repository>
      <id>nexus</id>
      <name>Releases</name>
      <url>http://localhost:8081/repository/maven-releases</url>
    </repository>
    <snapshotRepository>
      <id>nexus</id>
      <name>Snapshot</name>
      <url>http://localhost:8081/repository/maven-snapshots</url>
    </snapshotRepository>
  """)
open("pom.xml", "w").write(xml)
'
# deploy.
mvn deploy
popd


#
# test the raw repository.

apt-get install -y curl

# upload.
# see https://books.sonatype.com/nexus-book/3.0/reference/raw.html#_uploading_files_to_hosted_raw_repositories
expected='this is an adhoc package'
echo "$expected" >package-1.0.0.txt
curl --silent --user 'admin:admin123' --upload-file package-1.0.0.txt http://localhost:8081/repository/adhoc-package/package-1.0.0.txt
# download.
actual=$(curl --silent http://localhost:8081/repository/adhoc-package/package-1.0.0.txt)
[ "$actual" = "$expected" ] || (echo 'upload adhoc package test failed' && false)
