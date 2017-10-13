#!/bin/bash
set -eux

. /vagrant/provision/nexus-groovy.sh

mkdir -p tmp && cd tmp

#
# test the NuGet repository.
# see https://help.sonatype.com/display/NXRM3/.NET+Package+Repositories+with+NuGet

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


#
# test the maven repository.

# install maven and the java development kit.
sudo apt-get install -y maven
sudo apt-get install -y default-jdk
sudo apt-get install -y xmlstarlet

# setup the user maven configuration to use nexus as a mirror the
# official maven repository.
# see https://help.sonatype.com/display/NXRM3/Maven+Repositories
# see https://maven.apache.org/guides/mini/guide-mirror-settings.html
mkdir -p ~/.m2
cat >~/.m2/settings.xml <<'EOF'
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
  --batch-mode \
  archetype:generate \
  -DgroupId=com.example.helloworld \
  -DartifactId=example-helloworld \
  -DarchetypeArtifactId=maven-archetype-quickstart

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
mvn \
  --batch-mode \
  deploy
popd


#
# test the maven repository from gradle.

# download and install gradle.
apt-get install -y unzip
wget -qO/tmp/gradle-4.2.1-bin.zip https://services.gradle.org/distributions/gradle-4.2.1-bin.zip
unzip -d /opt/gradle /tmp/gradle-4.2.1-bin.zip
export PATH="$PATH:/opt/gradle/gradle-4.2.1/bin"

# build and upload an example library.
mkdir gradle-greeter-library
pushd gradle-greeter-library
mkdir -p src/main/java
cat >src/main/java/Greeter.java <<'EOF'
public final class Greeter {
    public static void greet(String name) {
        System.out.println("Hello " + name);
    }
}
EOF
cat >settings.gradle <<'EOF'
rootProject.name = 'gradle-greeter'
EOF
cat >build.gradle <<'EOF'
// see https://docs.gradle.org/4.2.1/userguide/java_library_plugin.html
// see https://docs.gradle.org/4.2.1/userguide/maven_plugin.html

apply plugin: 'java-library'
apply plugin: 'maven'

version = '1.0.0'
sourceCompatibility = 1.8
targetCompatibility = 1.8

jar {
    manifest {
        attributes(
            'Implementation-Title': 'Gradle Greeter Example',
            'Implementation-Version': version
        )
    }
}

uploadArchives {
    repositories {
        mavenDeployer {
            repository(url: System.env.NEXUS_REPOSITORY_URL) {
                authentication(
                    userName: System.env.NEXUS_REPOSITORY_USERNAME,
                    password: System.env.NEXUS_REPOSITORY_PASSWORD)
            }
            pom.groupId = 'com.example'
        }
    }
}
EOF
gradle build
unzip -l build/libs/gradle-greeter-1.0.0.jar
export NEXUS_REPOSITORY_URL='http://localhost:8081/repository/maven-releases'
export NEXUS_REPOSITORY_USERNAME='alice.doe'
export NEXUS_REPOSITORY_PASSWORD='password'
gradle upload
popd

# build an example application that uses our gradle-greeter library from our nexus repository.
mkdir gradle-greeter-application
pushd gradle-greeter-application
mkdir -p src/main/java
cat >src/main/java/Greet.java <<'EOF'
public final class Greet {
    public static void main(String[] args) {
        Greeter.greet("World");
    }
}
EOF
cat >settings.gradle <<'EOF'
rootProject.name = 'gradle-greeter-application'
EOF
cat >build.gradle <<'EOF'
// see https://docs.gradle.org/4.2.1/userguide/java_plugin.html
// see https://docs.gradle.org/4.2.1/userguide/application_plugin.html
// see http://imperceptiblethoughts.com/shadow/

plugins {
    id 'com.github.johnrengelman.shadow' version '2.0.1'
}

apply plugin: 'application'

mainClassName = 'Greet'
version = '1.0.0'
sourceCompatibility = 1.8
targetCompatibility = 1.8

jar {
    manifest {
        attributes(
            'Implementation-Title': 'Gradle Greeter Application Example',
            'Implementation-Version': version,
            'Main-Class': mainClassName
        )
    }
}

repositories {
    maven {
        url 'http://localhost:8081/repository/maven-public'
    }
}

dependencies {
    compile 'com.example:gradle-greeter:1.0.0'
}
EOF
gradle shadowJar
unzip -l build/libs/gradle-greeter-application-1.0.0-all.jar
java -jar build/libs/gradle-greeter-application-1.0.0-all.jar
popd


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


#
# test the npm repositories.
# see https://help.sonatype.com/display/NXRM3/Node+Packaged+Modules+and+npm+Registries

# install node LTS.
# see https://github.com/nodesource/distributions#debinstall
curl -sL https://deb.nodesource.com/setup_6.x | bash
apt-get install -y nodejs
node --version
npm --version

# configure npm to use the npm-group repository.
npm config set registry http://localhost:8081/repository/npm-group/

# install a package that indirectly uses the npmjs.org-proxy repository.
mkdir /tmp/hello-world-npm
pushd /tmp/hello-world-npm
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

# publish a package to the npm-hosted repository.
# see https://www.npmjs.com/package/npm-cli-login
npm install npm-cli-login
export NPM_USER=alice.doe
export NPM_PASS=password
export NPM_EMAIL=alice.doe@example.com
# NB npm-cli-login always adds the trailing slash to the registry url,
#    BUT npm publish refuses to work without it, so workaround this.
export NPM_REGISTRY=http://localhost:8081/repository/npm-hosted
./node_modules/.bin/npm-cli-login
export NPM_REGISTRY=$NPM_REGISTRY/
npm publish --registry $NPM_REGISTRY
popd
# and use it.
mkdir /tmp/use-hello-world-npm
pushd /tmp/use-hello-world-npm
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
