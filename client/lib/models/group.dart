class GroupModel {
  final String id;
  final String name;
  final String type;
  final String code;
  final String role;
  final int memberCount;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.type,
    required this.code,
    required this.role,
    this.memberCount = 0,
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      type: json['type'] ?? '가족',
      code: json['code'] ?? '',
      role: json['role'] ?? 'MEMBER',
      memberCount: json['_count']?['members'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  bool get isOwner => role == 'OWNER';
}

class GroupMember {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'] ?? 'MEMBER',
      joinedAt: DateTime.parse(json['joinedAt']),
    );
  }
}
