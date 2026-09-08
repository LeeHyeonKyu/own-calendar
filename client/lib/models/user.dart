class User {
  final String id;
  final String email;
  final String name;
  final int defaultReminderMinutes;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.defaultReminderMinutes = 10,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      defaultReminderMinutes: json['defaultReminderMinutes'] ?? 10,
    );
  }
}
