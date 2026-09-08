class FollowUser {
  final String id;
  final String name;
  final String email;

  FollowUser({
    required this.id,
    required this.name,
    required this.email,
  });

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    return FollowUser(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

class FollowModel {
  final String id;
  final FollowUser user;
  final DateTime createdAt;

  FollowModel({
    required this.id,
    required this.user,
    required this.createdAt,
  });

  factory FollowModel.fromJson(Map<String, dynamic> json) {
    return FollowModel(
      id: json['id'],
      user: FollowUser.fromJson(json['user']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class UserSearchResult {
  final String id;
  final String name;
  final String email;
  final String? followStatus; // null, PENDING, ACCEPTED, REJECTED
  final bool isFollowedBy;

  UserSearchResult({
    required this.id,
    required this.name,
    required this.email,
    this.followStatus,
    this.isFollowedBy = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      followStatus: json['followStatus'],
      isFollowedBy: json['isFollowedBy'] ?? false,
    );
  }
}
