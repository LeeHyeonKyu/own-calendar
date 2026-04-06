class CalendarModel {
  final String id;
  final String name;
  final String color;
  final bool isDefault;
  final String visibility;
  final String type;

  CalendarModel({
    required this.id,
    required this.name,
    required this.color,
    required this.isDefault,
    required this.visibility,
    required this.type,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'],
      name: json['name'],
      color: json['color'] ?? '#4A90D9',
      isDefault: json['isDefault'] ?? false,
      visibility: json['visibility'] ?? 'PUBLIC',
      type: json['type'] ?? 'PERSONAL',
    );
  }
}
