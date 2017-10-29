Open this directory with [IntelliJ IDEA Community Edition](https://www.jetbrains.com/idea/download/#section=windows).

Inside IDEA you can browse the sources with `control+left-click` to see which methods are available.

To execute the `src/main/groovy/provision.groovy` file inside the Vagrant
environment run `bash /vagrant/provision/execute-provision.groovy-script.sh`.

For more information see the Nexus [scripting documentation](https://help.sonatype.com/display/NXRM3/REST+and+Integration+API) and [examples](https://github.com/sonatype/nexus-book-examples/tree/nexus-3.x/scripting).

# Source Code

Run `make sources` to download and extract all the source code into the `sources` directory.

You are now able to `find` and `grep` it.

For example, list all `.groovy` files:

```sh
find sources -type f -name '*groovy'
```

Get all exposed API objects:

```sh
grep -ri ApiImpl sources
```

Where you can see the definition of the global variables that are available on a groovy script:

```
sources/org.sonatype.nexus.script/nexus-script.gdsl:  property name: 'security', type: 'org.sonatype.nexus.security.internal.SecurityApiImpl'
sources/org.sonatype.nexus.script/nexus-script.gdsl:  property name: 'core', type: 'org.sonatype.nexus.internal.provisioning.CoreApiImpl'
sources/org.sonatype.nexus.script/nexus-script.gdsl:  property name: 'repository', type: 'org.sonatype.nexus.script.plugin.internal.provisioning.RepositoryApiImpl'
sources/org.sonatype.nexus.script/nexus-script.gdsl:  property name: 'blobStore', type: 'org.sonatype.nexus.internal.provisioning.BlobStoreApiImpl'
```
