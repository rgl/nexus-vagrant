// run this file inside the Vagrant environment with bash /vagrant/provision/execute-provision.groovy-script.sh
// see https://help.sonatype.com/display/NXRM3/REST+and+Integration+API
// see https://github.com/sonatype/nexus-book-examples/tree/nexus-3.x/scripting/nexus-script-example

import groovy.json.JsonOutput
import org.sonatype.nexus.capability.CapabilityRegistry
import org.sonatype.nexus.repository.config.WritePolicy
import org.sonatype.nexus.security.user.UserSearchCriteria
import org.sonatype.nexus.security.realm.RealmManager
import org.apache.shiro.subject.SimplePrincipalCollection
import org.sonatype.nexus.scheduling.TaskScheduler
import org.sonatype.nexus.scheduling.schedule.Daily

// disable all the outreach capabilities.
capabilityRegistry = container.lookup(CapabilityRegistry.class)
capabilityRegistry.all.findAll {it.context().type().toString().startsWith("Outreach")}.each {
    capabilityRegistry.disable(it.context().id())
}
// you can retrieve all capabilities with:
//return JsonOutput.toJson([
//    capabilities: capabilityRegistry.all.collect {[
//        id: it.context().id().toString(),
//        type: it.context().type().toString(),
//        enabled: it.context().enabled,
//    ]}
//])

// create a raw repository backed by the default blob store.
// NB this repository can host any type of artifact, so we disable strictContentTypeValidation.
// see https://github.com/sonatype/nexus-book-examples/blob/nexus-3.x/scripting/complex-script/rawRepositories.groovy
// see https://help.sonatype.com/display/NXRM3/Raw+Repositories+and+Maven+Sites#RawRepositoriesandMavenSites-UploadingFilestoHostedRawRepositories
repository.createRawHosted("adhoc-package", "default", false, WritePolicy.ALLOW_ONCE)


// create a apt repository backed by the default blob store.
// see https://help.sonatype.com/repomanager3/formats/apt-repositories
pgpPrivateKey = new File('/vagrant/shared/apt-hosted-private.key').getText('UTF-8')
repository.createAptHosted("apt-hosted", "jammy", pgpPrivateKey, "abracadabra", "default", WritePolicy.ALLOW_ONCE, true)


// create a npm repository backed by the default blob store.
repository.createNpmHosted("npm-hosted", "default", true, WritePolicy.ALLOW_ONCE)
// create a npm proxy repository backed by the default blob store.
// see https://help.sonatype.com/display/NXRM3/Node+Packaged+Modules+and+npm+Registries
repository.createNpmProxy("npmjs.org-proxy", "https://registry.npmjs.org", "default")
// create a npm group repository that merges the npm-host and npmjs.org-proxy together.
repository.createNpmGroup("npm-group", ["npm-hosted", "npmjs.org-proxy"], "default")


// modify the default nuget-hosted repository for not allowing re-deployments.
config = repository.repositoryManager.get("nuget-hosted").configuration.copy()
config.attributes.storage.writePolicy = WritePolicy.ALLOW_ONCE
repository.repositoryManager.update(config)


// create a powershell repository backed by the default blob store.
repository.createNugetHosted("powershell-hosted", "default", true, WritePolicy.ALLOW_ONCE)
// create a powershell proxy repository backed by the default blob store.
// see https://help.sonatype.com/repomanager3/formats/nuget-repositories
config = repository.createNugetProxy("powershellgallery.com-proxy", "https://www.powershellgallery.com/api/v2/", "default").configuration.copy()
config.attributes.nugetProxy.nugetVersion = "V2"
repository.repositoryManager.update(config)
// create a powershell group repository that merges the powershell-host and powershellgallery.com-proxy together.
repository.createNugetGroup("powershell-group", ["powershell-hosted", "powershellgallery.com-proxy"], "default")


// create a chocolatey repository backed by the default blob store.
repository.createNugetHosted("chocolatey-hosted", "default", true, WritePolicy.ALLOW_ONCE)
// create a chocolatey proxy repository backed by the default blob store.
// see https://help.sonatype.com/repomanager3/formats/nuget-repositories
config = repository.createNugetProxy("chocolatey.org-proxy", "https://chocolatey.org/api/v2/", "default").configuration.copy()
config.attributes.nugetProxy.nugetVersion = "V2"
repository.repositoryManager.update(config)
// create a chocolatey group repository that merges the chocolatey-host and chocolatey.org-proxy together.
repository.createNugetGroup("chocolatey-group", ["chocolatey-hosted", "chocolatey.org-proxy"], "default")


// create a docker registry repository backed by the default blob store.
repository.createDockerHosted("docker-hosted", 6003, null, "default", true, true, WritePolicy.ALLOW, true)
// create a docker proxy repository backed by the default blob store.
// see https://help.sonatype.com/repomanager3/formats/docker-registry
// TODO set Allow Nexus Repository Manager to download and cache foreign layers.
// NB as-of docker 19.03.5, there is still no way to specify a registry mirror credentials...
//    as such, we cannot use our docker-group registry, instead we must use the docker-proxy
//    registry, enable the Docker Bearer Token Realm and allow anonymous access to it.
//    see https://github.com/moby/moby/issues/30880
// NB this will make https://nexus.example.com:5002/v2/library/debian/manifests/buster-slim proxy
//    to https://registry-1.docker.io/v2/library/debian/manifests/buster-slim
//       https://registry-1.docker.io/v2/library/golang/tags/list
repository.createDockerProxy("docker-hub-proxy", "https://registry-1.docker.io", "HUB", null, 6002, null, "default", true, true, false)
// create a docker group repository that merges the docker-hosted and docker-hub-proxy together.
repository.createDockerGroup("docker-group", 6001, null, ["docker-hosted", "docker-hub-proxy"], true, "default", true)


// set the base url. this is used when sending emails.
// see https://help.sonatype.com/display/NXRM3/Configuration#Configuration-BaseURLCreation
core.baseUrl("https://" + java.net.InetAddress.localHost.canonicalHostName)


// schedule a task to remove old snapshots from the maven-snapshots repository.
// see https://github.com/sonatype/nexus-public/blob/555cc59e7fa659c0a1a4fbc881bf3fcef0e9a5b6/components/nexus-scheduling/src/main/java/org/sonatype/nexus/scheduling/TaskScheduler.java
// see https://github.com/sonatype/nexus-public/blob/555cc59e7fa659c0a1a4fbc881bf3fcef0e9a5b6/plugins/nexus-coreui-plugin/src/main/java/org/sonatype/nexus/coreui/TaskComponent.groovy
taskScheduler = (TaskScheduler)container.lookup(TaskScheduler.class.name)
taskConfiguration = taskScheduler.createTaskConfigurationInstance("repository.maven.remove-snapshots")
taskConfiguration.name = "remove old snapshots from the maven-snapshots repository"
// NB to see the available properties uncomment the tasksDescriptors property from JsonOutput.toJson at the end of this script.
taskConfiguration.setString("repositoryName", "maven-snapshots")
taskConfiguration.setString("minimumRetained", "1")
taskConfiguration.setString("snapshotRetentionDays", "30")
// TODO taskConfiguration.setAlertEmail("TODO")
taskScheduler.scheduleTask(taskConfiguration, new Daily(new Date().clearTime().next()))


// NB you can list the available realms with realmManager.availableRealms.
realmManager = container.lookup(RealmManager.class.name)
// enable the NuGet API-Key Realm.
realmManager.enableRealm("NuGetApiKey")
// enable the npm Bearer Token Realm.
realmManager.enableRealm("NpmToken")
// enable the Docker Bearer Token Realm.
realmManager.enableRealm("DockerToken")
// allow Anonymous access to nexus to be able to use the docker-hub-proxy repository.
// NB this might be worked around by creating an docker-anonymous user and force its
//    credentials in the nginx reverse-proxy configuration.
//    see https://github.com/moby/moby/issues/30880#issuecomment-601513505
security.anonymousAccess = true

// set the admin password.
// NB we set it to something different than the default (admin123) to get
//    rid of the "Default Admin Credentials" warning... and because this
//    password is easier to remember.
security.securitySystem.changePassword('admin', 'admin')


// create users in the deployer role.
// see https://github.com/sonatype/nexus-book-examples/blob/nexus-3.x/scripting/complex-script/security.groovy#L38
def addDeployerUser(firstName, lastName, email, userName, password) {
    if (!security.securitySystem.listRoles().any { it.roleId == "deployer" }) {
        privileges = [
            "nx-search-read",
            "nx-repository-view-*-*-read",
            "nx-repository-view-*-*-browse",
            "nx-repository-view-*-*-add",
            "nx-repository-view-*-*-edit",
            "nx-apikey-all"]
        security.addRole("deployer", "deployer", "deployment on all repositories", privileges, [])
    }
    try {
        user = security.securitySystem.getUser(userName);
    } catch (org.sonatype.nexus.security.user.UserNotFoundException e) {
        user = security.addUser(userName, firstName, lastName, email, true, password, ["deployer"])
    }
}
addDeployerUser("Jenkins", "Doe", "jenkins@example.com", "jenkins", "password")
addDeployerUser("Alice", "Doe", "alice.doe@example.com", "alice.doe", "password")
addDeployerUser("Bob", "Doe", "bob.doe@example.com", "bob.doe", "password")

realms = realmManager.configuration.realmNames
users = security.securitySystem.searchUsers(new UserSearchCriteria())
repositories = repository.repositoryManager.browse().collect { [name:it.name,type:it.type.value] }

return JsonOutput.toJson([
    /*tasksDescriptors: taskScheduler.taskFactory.descriptors.collect { [
        id: it.id,
        name: it.name,
        exposed: it.exposed,
        formFields: it.formFields?.collect { [
            id: it.id,
            type: it.type,
            label: it.label,
            helpText: it.helpText,
            required: it.required,
            regexValidation: it.regexValidation,
            initialValue: it.initialValue,
            ] }
    ] },*/
    realms: realms.sort { it },
    users: users.sort { it.userId },
    repositories: repositories.sort { it.name },
])
