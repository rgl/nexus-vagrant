This is a Vagrant Environment for a [Nexus Repository OSS](https://github.com/sonatype/nexus-public) service.

This will:

* Configure Nexus through the API.
  * Create the `adhoc-package` repository.
  * Create the `apt-hosted` repository.
  * Create the `npm-group`, `npm-hosted` and `npmjs.org-proxy` repositories.
  * Create the `powershell-group`, `powershell-hosted` and `powershellgallery.com-proxy` repositories.
  * Configure the NuGet `nuget-hosted` repository to accept pushing with an API key.
* Configure Nexus through Groovy scripts.
  * Create the `chocolatey-group`, `chocolatey-hosted` and `chocolatey.org-proxy` repositories.
  * Schedule a task to remove the old snapshots from the `maven-snapshots` repository.
  * Create users and a custom `deployer` role.
  * Setup an Active Directory LDAP user authentication source (when `config_authentication='ldap'` is set inside the `provision-nexus.sh` file).
  * For more details look inside the [provision/provision-nexus](provision/provision-nexus) directory.
* Setup nginx as a Nexus HTTPS proxy and static file server.
* Test the installed repositories by using and publishing to them (see the `use-*` files).

**NB** If you are new to Groovy, be sure to check the [Groovy Learn X in Y minutes page](https://learnxinyminutes.com/docs/groovy/).


# Caveats

* Not all the repository plugins are open-source.
  * The open-source ones are available at [sonatype/nexus-public/plugins](https://github.com/sonatype/nexus-public/tree/master/plugins).


# Usage

Build and install the [Ubuntu 22.04 Base Box](https://github.com/rgl/ubuntu-vagrant).

Build and install the [Windows 2022 Base Box](https://github.com/rgl/windows-vagrant).

Add the following entry to your `/etc/hosts` file:

```
192.168.56.3 nexus.example.com
```

Install Vagrant 2.1+.

Run `vagrant up --provider=virtualbox # or --provider=libvirt` to launch the environment.

Access the [Nexus home page](https://nexus.example.com) and login as the `admin` user and password `admin`.

You can also login with one of the example accounts, e.g. `alice.doe` and password `password`.

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
        https://nexus.example.com/service/rest/v1/search \
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
    -Uri https://nexus.example.com/service/rest/v1/search `
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

## H2 Database

Nexus uses [H2 Database](https://en.wikipedia.org/wiki/H2_(database)) as its database management system.

**NB** Nexus OSS can only use the H2 database management system.

**NB** Nexus Pro can use the H2 or PostgreSQL database management system.

The Web based H2 Database Console is available at https://nexus.example.com/h2-console with the following settings:

| Setting        | Value                                            |
|----------------|--------------------------------------------------|
| Saved Settings | Generic H2 (Embedded)                            |
| Setting Name   | Generic H2 (Embedded)                            |
| Driver Class   | org.h2.Driver                                    |
| JDBC URL       | jdbc:h2:/opt/nexus/sonatype-work/nexus3/db/nexus |
| User Name      | _empty_                                          |
| Password       | _empty_                                          |

You can also access the database cli shell as:

```bash
sudo su -l                            # switch to the root user.
systemctl stop nexus                  # make sure nexus is not running while you use the database.
su -s /bin/bash nexus                 # switch to the nexus user.
nexus_home=/opt/nexus/nexus-3.75.1-01 # make sure you have the correct version here.
nexus_data="$(realpath $nexus_home/../sonatype-work/nexus3)"
function h2-shell {
  java \
    -cp $nexus_home/system/com/h2database/h2/*/h2*.jar \
    org.h2.tools.Shell \
    -url jdbc:h2:$nexus_data/db/nexus
}
h2-shell
```

Then execute some commands and exit the console, e.g.:

```sql
-- see https://h2database.com/html/commands.html
help
show schemas;
show tables;
show columns from security_user;
select * from security_user;
select * from api_key_v2;
select * from repository;
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

For more information see the [available Command Line Tools](https://h2database.com/html/tutorial.html#command_line_tools).

## Reference

* [How to reset a forgotten admin password in Nexus 3.x](https://support.sonatype.com/hc/en-us/articles/213467158-How-to-reset-a-forgotten-admin-password-in-Nexus-3-x)
* [Backup and Restore](https://help.sonatype.com/repomanager3/backup-and-restore)
* [Upgrading](https://help.sonatype.com/repomanager3/upgrading)
