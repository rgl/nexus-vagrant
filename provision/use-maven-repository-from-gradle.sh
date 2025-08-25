#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

rm -rf tmp/use-maven-repository-from-gradle
mkdir -p tmp/use-maven-repository-from-gradle
cd tmp/use-maven-repository-from-gradle

#
# test the maven repository from gradle.

# download and install gradle.
# see https://gradle.org/releases/
# renovate: datasource=github-releases depName=gradle/gradle
gradle_version='9.0.0'
if [ ! -f /opt/gradle/gradle-$gradle_version/bin/gradle ]; then
    apt-get install -y unzip
    wget -qO/tmp/gradle-$gradle_version-bin.zip https://services.gradle.org/distributions/gradle-$gradle_version-bin.zip
    unzip -d /opt/gradle /tmp/gradle-$gradle_version-bin.zip
fi
export PATH="$PATH:/opt/gradle/gradle-$gradle_version/bin"

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
// see https://docs.gradle.org/9.0.0/userguide/java_library_plugin.html
// see https://docs.gradle.org/9.0.0/userguide/maven_plugin.html

plugins {
    id 'java-library'
    id 'maven-publish'
}

group = 'com.example'
version = '1.0.0'

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

jar {
    manifest {
        attributes(
            'Implementation-Title': 'Gradle Greeter Example',
            'Implementation-Version': project.version
        )
    }
}

publishing {
    publications {
        maven(MavenPublication) {
            from components.java
        }
    }

    repositories {
        maven {
            url = System.env.NEXUS_REPOSITORY_URL
            credentials {
                username = System.env.NEXUS_REPOSITORY_USERNAME
                password = System.env.NEXUS_REPOSITORY_PASSWORD
            }
        }
    }
}
EOF
gradle --warning-mode all build
unzip -l build/libs/gradle-greeter-1.0.0.jar
unzip -p build/libs/gradle-greeter-1.0.0.jar META-INF/MANIFEST.MF
export NEXUS_REPOSITORY_URL="https://$nexus_domain/repository/maven-releases"
export NEXUS_REPOSITORY_USERNAME='alice.doe'
export NEXUS_REPOSITORY_PASSWORD='password'
gradle --warning-mode all publish
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
# see https://mvnrepository.com/artifact/com.gradleup.shadow/shadow-gradle-plugin
# renovate: datasource=maven depName=com.gradleup.shadow:shadow-gradle-plugin
com_gradleup_shadow_version='9.0.2'
cat >build.gradle <<EOF
// see https://docs.gradle.org/9.0.0/userguide/java_plugin.html
// see https://docs.gradle.org/9.0.0/userguide/application_plugin.html
// see https://gradleup.com/shadow/
// see https://github.com/GradleUp/shadow

plugins {
    id 'application'
    id 'com.gradleup.shadow' version '$com_gradleup_shadow_version'
}

group = 'com.example'
version = '1.0.0'

application {
    mainClass = 'Greet'
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

jar {
    manifest {
        attributes(
            'Implementation-Title': 'Gradle Greeter Application Example',
            'Implementation-Version': project.version
        )
    }
}

repositories {
    maven {
        url = 'https://$nexus_domain/repository/maven-public'
    }
}

dependencies {
    implementation 'com.example:gradle-greeter:1.0.0'
}
EOF
gradle --warning-mode all shadowJar
unzip -l build/libs/gradle-greeter-application-1.0.0-all.jar
unzip -p build/libs/gradle-greeter-application-1.0.0-all.jar META-INF/MANIFEST.MF
java -jar build/libs/gradle-greeter-application-1.0.0-all.jar
popd
