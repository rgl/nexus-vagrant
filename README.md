This is a Vagrant Environment for a [Nexus Repository OSS](https://github.com/sonatype/nexus-public) service.

This will:

* Configure Nexus through Groovy scripts.
  * Create the `adhoc-package` repository.
  * Create the `npm-group`, `npm-hosted` and `npmjs.org-proxy` repositories.
  * Create the `chocolatey-group`, `chocolatey-hosted` and `chocolatey.org-proxy` repositories.
  * Create the `powershell-group`, `powershell-hosted` and `powershellgallery.com-proxy` repositories.
  * Configure the NuGet `nuget-hosted` repository to accept pushing with an API key.
  * Schedule a task to remove the old snapshots from the `maven-snapshots` repository.
  * Create users and a custom `deployer` role.
  * Setup an Active Directory LDAP user authentication source (when `config_authentication='ldap'` is set inside the `provision-nexus.sh` file).
  * For more details look inside the [provision/provision-nexus](provision/provision-nexus) directory.
* Setup nginx as a Nexus HTTPS proxy and static file server.
* Test the installed repositories by [using and publishing to them](provision/test.sh).

**NB** If you are new to Groovy, be sure to check the [Groovy Learn X in Y minutes page](https://learnxinyminutes.com/docs/groovy/).


# Caveats

* Most of the repository plugins are not open-source.
  * Only `maven` and `raw` are open-source.


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Build and install the [Windows Base Box](https://github.com/rgl/windows-2016-vagrant).

Add the following entry to your `/etc/hosts` file:

```
192.168.56.3 nexus.example.com
```

Run `vagrant up --provider=virtualbox # or --provider=libvirt` to launch the environment.
See its output to known how to login at the
[local Nexus home page](https://nexus.example.com) as `admin` (you can also login with
one of the example accounts, e.g. `alice.doe` and password `password`).

**NB** nginx is setup with a self-signed certificate that you have to trust before being
able to access the local Nexus home page.


# Troubleshooting

## Logs

The logs are at `/opt/nexus/log/nexus.log`.

You can also see them with `journalctl -u nexus`.

## OrientDB

Nexus uses [OrientDB](https://en.wikipedia.org/wiki/OrientDB) as its database. To directly use it from the console run:

```bash
systemctl stop nexus
su nexus -s /bin/bash -c 'cd /opt/nexus && java -jar ./lib/support/nexus-orient-console.jar'
```

Then connect to one of the databases, e.g. to the `security` database:

```plain
connect plocal:nexus3/db/security admin admin
```

Then execute some commands, e.g.:

```plain
help
list classes
```

For more information about the console see [Running the OrientDB Console](http://orientdb.com/docs/master/Tutorial-Run-the-console.html).


## Reference

* [How to reset a forgotten admin password in Nexus 3.x](https://support.sonatype.com/hc/en-us/articles/213467158-How-to-reset-a-forgotten-admin-password-in-Nexus-3-x)
