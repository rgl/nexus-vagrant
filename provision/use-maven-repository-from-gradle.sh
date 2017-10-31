#!/bin/bash
set -eux

mkdir -p tmp/use-maven-repository-from-gradle && cd tmp/use-maven-repository-from-gradle

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
