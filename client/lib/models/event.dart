class EventModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final bool isPrivate;
  final String calendarId;
  final String? calendarName;
  final String? calendarColor;

  EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.isPrivate = false,
    required this.calendarId,
    this.calendarName,
    this.calendarColor,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      isAllDay: json['isAllDay'] ?? false,
      isPrivate: json['isPrivate'] ?? false,
      calendarId: json['calendarId'],
      calendarName: json['calendar']?['name'],
      calendarColor: json['calendar']?['color'],
    );
  }
}
