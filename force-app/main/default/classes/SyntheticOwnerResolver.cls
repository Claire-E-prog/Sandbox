public class SyntheticOwnerResolver {
  public static List<Id> resolveActiveUserIds(List<String> ownerUsernames) {
    Set<String> requestedUsernames = new Set<String>();
    Set<String> normalizedUsernames = new Set<String>();

    for (String username : ownerUsernames) {
      if (String.isBlank(username)) {
        throw new SyntheticDataException(
          'ownerUsernames cannot contain a blank value.'
        );
      }
      String trimmedUsername = username.trim();
      String normalizedUsername = trimmedUsername.toLowerCase();
      if (!normalizedUsernames.add(normalizedUsername)) {
        throw new SyntheticDataException(
          'Duplicate username in ownerUsernames: ' + trimmedUsername
        );
      }
      requestedUsernames.add(trimmedUsername);
    }

    Map<String, User> usersByNormalizedUsername = new Map<String, User>();
    for (User owner : [
      SELECT Id, Username, IsActive
      FROM User
      WHERE Username IN :requestedUsernames
    ]) {
      usersByNormalizedUsername.put(owner.Username.toLowerCase(), owner);
    }

    List<Id> ownerIds = new List<Id>();
    for (String username : ownerUsernames) {
      User owner = usersByNormalizedUsername.get(
        username.trim().toLowerCase()
      );
      if (owner == null) {
        throw new SyntheticDataException(
          'No Salesforce user found for username: ' + username
        );
      }
      if (!owner.IsActive) {
        throw new SyntheticDataException(
          'Synthetic data owner is inactive: ' + username
        );
      }
      ownerIds.add(owner.Id);
    }
    return ownerIds;
  }
}
