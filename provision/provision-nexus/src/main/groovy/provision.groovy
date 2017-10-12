// run this file inside the Vagrant environment with bash /vagrant/execute-provision.groovy-script.sh
// see https://help.sonatype.com/display/NXRM3/REST+and+Integration+API
// see https://github.com/sonatype/nexus-book-examples/tree/nexus-3.x/scripting/nexus-script-example

import groovy.json.JsonOutput
import org.sonatype.nexus.security.user.UserSearchCriteria
import org.sonatype.nexus.security.authc.apikey.ApiKeyStore
import org.sonatype.nexus.security.realm.RealmManager
import org.apache.shiro.subject.SimplePrincipalCollection
import org.sonatype.nexus.scheduling.TaskScheduler
import org.sonatype.nexus.scheduling.schedule.Daily

// create a raw repository backed by the default blob store.
// see https://github.com/sonatype/nexus-book-examples/blob/nexus-3.x/scripting/complex-script/rawRepositories.groovy
// see https://help.sonatype.com/display/NXRM3/Raw+Repositories+and+Maven+Sites#RawRepositoriesandMavenSites-UploadingFilestoHostedRawRepositories
repository.createRawHosted("adhoc-package", "default")


// create a npm repository backed by the default blob store.
repository.createNpmHosted("npm-hosted", "default")


// create a npm proxy repository backed by the default blob store.
// see https://help.sonatype.com/display/NXRM3/Node+Packaged+Modules+and+npm+Registries
repository.createNpmProxy("npmjs.org-proxy", "https://registry.npmjs.org", "default")


// create a npm group repository that merges the npm-host and npmjs.org-proxy together.
repository.createNpmGroup("npm-group", ["npm-hosted", "npmjs.org-proxy"], "default")


// see http://stackoverflow.com/questions/8138164/groovy-generate-random-string-from-given-character-set
def random(String alphabet, int n) {
    new Random().with {
        (1..n).collect { alphabet[nextInt(alphabet.length())] }.join()
    }
}
jenkinsPassword = random((('A'..'Z')+('a'..'z')+('0'..'9')).join(), 16)


// set the base url. this is used when sending emails.
// see https://help.sonatype.com/display/NXRM3/Configuration#Configuration-BaseURLCreation
core.baseUrl("https://" + java.net.InetAddress.getLocalHost().getCanonicalHostName())


// schedule a task to remove old snapshots from the maven-snapshots repository.
// see https://github.com/sonatype/nexus-public/blob/555cc59e7fa659c0a1a4fbc881bf3fcef0e9a5b6/components/nexus-scheduling/src/main/java/org/sonatype/nexus/scheduling/TaskScheduler.java
// see https://github.com/sonatype/nexus-public/blob/555cc59e7fa659c0a1a4fbc881bf3fcef0e9a5b6/plugins/nexus-coreui-plugin/src/main/java/org/sonatype/nexus/coreui/TaskComponent.groovy
taskScheduler = (TaskScheduler)container.lookup(TaskScheduler.class.getName())
taskConfiguration = taskScheduler.createTaskConfigurationInstance("repository.maven.remove-snapshots")
taskConfiguration.name = "remove old snapshots from the maven-snapshots repository"
// NB to see the available properties uncomment the tasksDescriptors property from JsonOutput.toJson at the end of this script.
taskConfiguration.setString("repositoryName", "maven-snapshots")
taskConfiguration.setString("minimumRetained", "1")
taskConfiguration.setString("snapshotRetentionDays", "30")
// TODO taskConfiguration.setAlertEmail("TODO")
taskScheduler.scheduleTask(taskConfiguration, new Daily(new Date().clearTime().next()))


// enable the NuGet API-Key Realm.
realmManager = container.lookup(RealmManager.class.getName())
realmManager.enableRealm("NuGetApiKey")

// enable the npm Bearer Token Realm.
realmManager.enableRealm("NpmToken")


// the intent is to get or create an NuGet API Key like the one we can see on the user page:
// http://nexus.example.com:8081/#user/nugetapitoken.
def getOrCreateNuGetApiKey(String userName) {
    realmName = "NexusAuthenticatingRealm"
    apiKeyDomain = "NuGetApiKey"
    principal = new SimplePrincipalCollection(userName, realmName)
    keyStore = container.lookup(ApiKeyStore.class.getName())
    apiKey = keyStore.getApiKey(apiKeyDomain, principal)
    if (apiKey == null) {
        apiKey = keyStore.createApiKey(apiKeyDomain, principal)
    }
    return apiKey.toString()
}


// create users in the deployer role.
// see https://github.com/sonatype/nexus-book-examples/blob/nexus-3.x/scripting/complex-script/security.groovy#L38
def addDeployerUser(firstName, lastName, email, userName, password) {
    if (!security.securitySystem.listRoles().any { it.getRoleId() == "deployer" }) {
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
    nuGetApiKey = getOrCreateNuGetApiKey(userName)
}
addDeployerUser("Jenkins", "Doe", "jenkins@example.com", "jenkins", jenkinsPassword)
addDeployerUser("Alice", "Doe", "alice.doe@example.com", "alice.doe", "password")
addDeployerUser("Bob", "Doe", "bob.doe@example.com", "bob.doe", "password")


// get the jenkins NuGet API Key.
jenkinsNuGetApiKey = getOrCreateNuGetApiKey("jenkins")

realms = realmManager.getConfiguration().getRealmNames()
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
