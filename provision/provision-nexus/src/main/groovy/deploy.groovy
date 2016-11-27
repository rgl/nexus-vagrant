import org.sonatype.nexus.security.user.UserSearchCriteria

// delete all users except the allowed ones.
allowedUsers = [
    "anonymous",
    "admin",
    "jenkins",
]
security.securitySystem
    .searchUsers(new UserSearchCriteria())
    .findAll { !allowedUsers.contains(it.userId) }
    .forEach { security.securitySystem.deleteUser(it.userId) }
