This is a Vagrant Environment for a [Nexus Repository OSS](https://github.com/sonatype/nexus-public) service.

This will:

* Configure Nexus through Groovy scripts.
  * Create the `adhoc-package` repository.
  * Create the `npm-group`, `npm-hosted` and `npmjs.org-proxy` repositories.
  * Configure the NuGet `nuget-hosted` repository to accept pushing with an API key.
  * Schedule a task to remove the old snapshots from the `maven-snapshots` repository.
  * Create users and a custom `deployer` role.
  * For more details look inside the [provision/provision-nexus](provision/provision-nexus) directory.
* Setup nginx as a Nexus HTTPS proxy and static file server.
* Test the installed repositories by [using and publishing to them](provision/test.sh).

**NB** If you are new to Groovy, be sure to check the [Groovy Learn X in Y minutes page](https://learnxinyminutes.com/docs/groovy/).


# Caveats

* Most of the repository plugins are not open-source.
  * Only `maven` and `raw` are open-source.


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Add the following entry to your `/etc/hosts` file:

```
192.168.56.3 nexus.example.com
```

Run `vagrant up` to launch the environment. See its output to known how to login at the
[local Nexus home page](https://nexus.example.com) as `admin` (you can also login with
one of the example accounts, e.g. `alice.doe` and password `password`).

**NB** nginx is setup with a self-signed certificate that you have to trust before being
able to access the local Nexus home page.
