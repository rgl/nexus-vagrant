// run this file inside the Vagrant environment with bash /vagrant/provision/execute-provision-ldap.groovy-script.sh
// see https://help.sonatype.com/display/NXRM3/REST+and+Integration+API
// see https://github.com/sonatype/nexus-book-examples/tree/nexus-3.x/scripting/nexus-script-example

import groovy.json.JsonOutput
import org.sonatype.nexus.ldap.persist.LdapConfigurationManager
import org.sonatype.nexus.ldap.persist.entity.Connection
import org.sonatype.nexus.ldap.persist.entity.LdapConfiguration
import org.sonatype.nexus.ldap.persist.entity.Mapping

ldapManager = container.lookup(LdapConfigurationManager.class.name)

if (!ldapManager.listLdapServerConfigurations().any { it.name == "dc.example.com" }) {
    ldapManager.addLdapServerConfiguration(
            new LdapConfiguration(
                    name: 'dc.example.com',
                    connection: new Connection(
                            host: new Connection.Host(Connection.Protocol.ldaps, 'dc.example.com', 636),
                            connectionTimeout: 30,
                            connectionRetryDelay: 300,
                            maxIncidentsCount: 3,
                            searchBase: 'dc=example,dc=com',
                            authScheme: 'simple',
                            systemUsername: 'jane.doe@example.com',
                            systemPassword: 'HeyH0Password',
                    ),
                    mapping: new Mapping(
                            userBaseDn: 'cn=users',
                            userObjectClass: 'user',
                            ldapFilter: '(&(objectClass=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))',
                            userIdAttribute: 'sAMAccountName',
                            userRealNameAttribute: 'cn',
                            emailAddressAttribute: 'mail',
                            userPasswordAttribute: '',
                            ldapGroupsAsRoles: true,
                            userMemberOfAttribute: 'memberOf',
                    )
            )
    )
}

// create external role mappings.
if (!security.securitySystem.listRoles().any { it.roleId == "Administrators" && it.source == "default" }) {
    security.addRole(
        "Administrators",
        "nx-admin",
        "Administrator Role (LDAP Administrators)",
        [],
        ["nx-admin"])
}

ldapUsers = security.securitySystem.searchUsers(new UserSearchCriteria(source: 'LDAP'))
return JsonOutput.toJson([
        ldapUsers: ldapUsers.sort { it.userId },
        ldapGroups: security.securitySystem.listRoles('LDAP').sort { it.roleId },
        roles: security.securitySystem.listRoles().sort { it.roleId },
])
