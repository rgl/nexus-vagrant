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
* Test the installed repositories by using and publishing to them (see the `use-*` files).

**NB** If you are new to Groovy, be sure to check the [Groovy Learn X in Y minutes page](https://learnxinyminutes.com/docs/groovy/).


# Caveats

* Most of the repository plugins are not open-source.
  * Only `maven`, `raw`, `npm` and `PyPI` are open-source.


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Build and install the [Windows Base Box](https://github.com/rgl/windows-2016-vagrant).

Add the following entry to your `/etc/hosts` file:

```
192.168.56.3 nexus.example.com
```

Install Vagrant 2.1+.

Run `vagrant up --provider=virtualbox # or --provider=libvirt` to launch the environment.
See its output to known how to login at the
[local Nexus home page](https://nexus.example.com) as `admin` (you can also login with
one of the example accounts, e.g. `alice.doe` and password `password`).

**NB** nginx is setup with a self-signed certificate that you have to trust before being
able to access the local Nexus home page.

# Notes

## Check for a component existence

With bash, [HTTPie](https://httpie.org/) and [jq](https://stedolan.github.io/jq/):

```bash
function nexus-component-exists {
  [ \
    "$(
      http \
        get \
        https://nexus.example.com/service/rest/beta/search \
        "repository==$1" \
        "name==$2" \
        "version==$3" \
      | jq -r .items[].name)" == "$2" \
  ]
}

if nexus-component-exists npm-hosted hello-world 1.0.0; then
  echo 'component exists'
else
  echo 'component does not exists'
fi
```

With PowerShell:

```powershell
function Test-NexusComponent {
  param(
    [string]$repository,
    [string]$name,
    [string]$version)
  $items = (Invoke-RestMethod `
    -Method Get `
    -Uri https://nexus.example.com/service/rest/beta/search `
    -Body @{
      repository = $repository
      name = $name
      version = $version
    }).items
  $items.Count -and ($items.name -eq $name)
}

if (Test-NexusComponent npm-hosted hello-world 1.0.0) {
  Write-Host 'component exists'
} else {
  Write-Host 'component does not exists'
}
```

# Troubleshooting

## Logs

The logs are at `/opt/nexus/log/nexus.log`.

You can also see them with `journalctl -u nexus`.

## OrientDB

Nexus uses [OrientDB](https://en.wikipedia.org/wiki/OrientDB) as its database. To directly use it from the console run:

```bash
systemctl stop nexus                  # make sure nexus is not running while you use the database.
su -s /bin/bash nexus                 # switch to the nexus user.
nexus_home=/opt/nexus/nexus-3.13.0-01 # make sure you have the correct version here.
nexus_data=$nexus_home/../sonatype-work/nexus3
function orientdb-console {
    java -jar $nexus_home/lib/support/nexus-orient-console.jar $*
}
cd $nexus_data
ls -laF db | grep ^d  # list the databases
orientdb-console      # start the console.
```

Then connect to one of the databases, e.g. to the `security` database:

```plain
connect plocal:db/security admin admin
```

Then execute some commands and exit the orientdb console, e.g.:

```plain
help
config
list classes
exit
```

Exit the nexus user shell:

```bash
exit
```

And start nexus again:

```bash
systemctl start nexus
```

For more information about the console see [Running the OrientDB Console](http://orientdb.com/docs/master/Tutorial-Run-the-console.html).

## OrientDB Check Databases

Execute the commands from the OrientDB section to stop nexus, to enter the
nexus account and create the orientdb-console function, then:

```bash
# check the databases.
# NB use CHECK DATABASE -v to see the verbose log.
orientdb-console 'CONNECT PLOCAL:db/accesslog admin admin; CHECK DATABASE;'
orientdb-console 'CONNECT PLOCAL:db/analytics admin admin; CHECK DATABASE;'
orientdb-console 'CONNECT PLOCAL:db/audit admin admin; CHECK DATABASE;'
orientdb-console 'CONNECT PLOCAL:db/component admin admin; CHECK DATABASE;'
#orientdb-console 'CONNECT PLOCAL:db/component admin admin; REPAIR DATABASE;'
orientdb-console 'CONNECT PLOCAL:db/config admin admin; CHECK DATABASE;'
orientdb-console 'CONNECT PLOCAL:db/security admin admin; CHECK DATABASE;'
#orientdb-console 'CONNECT PLOCAL:db/OSystem admin admin; CONFIG; LIST CLASSES;' # XXX fails to connect. see https://groups.google.com/a/glists.sonatype.com/forum/#!topic/nexus-users/7dVofIwC5HM
```

Then start nexus.

## OrientDB Export Databases

Execute the commands from the OrientDB section to stop nexus, to enter the
nexus account and create the orientdb-console function, then:

```bash
# export the databases.
orientdb-console 'CONNECT PLOCAL:db/config admin admin; EXPORT DATABASE /tmp/nexus-export-config.json.gz;'
#orientdb-console 'CONNECT PLOCAL:db/security admin admin; EXPORT DATABASE /tmp/nexus-export-security.json.gz;'
orientdb-console 'CONNECT PLOCAL:db/component admin admin; EXPORT DATABASE /tmp/nexus-export-component.json.gz;'


## Reference

* [How to reset a forgotten admin password in Nexus 3.x](https://support.sonatype.com/hc/en-us/articles/213467158-How-to-reset-a-forgotten-admin-password-in-Nexus-3-x)
* [Backup and Restore](https://help.sonatype.com/repomanager3/backup-and-restore)
* [Upgrading](https://help.sonatype.com/repomanager3/upgrading)
