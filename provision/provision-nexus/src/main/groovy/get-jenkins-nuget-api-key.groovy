import groovy.json.JsonOutput
import org.sonatype.nexus.security.authc.apikey.ApiKeyStore
import org.apache.shiro.subject.SimplePrincipalCollection

def getNuGetApiKey(String userName) {
    realmName = "NexusAuthenticatingRealm"
    apiKeyDomain = "NuGetApiKey"
    principal = new SimplePrincipalCollection(userName, realmName)
    keyStore = container.lookup(ApiKeyStore.class.getName())
    apiKey = keyStore.getApiKey(apiKeyDomain, principal)
    return apiKey.toString()
}

return JsonOutput.toJson([
    apiKey: getNuGetApiKey("jenkins"),
])
