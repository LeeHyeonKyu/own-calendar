class EventModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final bool isPrivate;
  final String category;
  final List<String> tags;
  final String recurrenceType;
  final DateTime? recurrenceEnd;
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
    this.category = 'PERSONAL',
    this.tags = const [],
    this.recurrenceType = 'NONE',
    this.recurrenceEnd,
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
      category: json['category'] ?? 'PERSONAL',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      recurrenceType: json['recurrenceType'] ?? 'NONE',
      recurrenceEnd: json['recurrenceEnd'] != null
          ? DateTime.parse(json['recurrenceEnd'])
          : null,
      calendarId: json['calendarId'],
      calendarName: json['calendar']?['name'],
      calendarColor: json['calendar']?['color'],
    );
  }

  bool get isRecurring => recurrenceType != 'NONE';

  String get baseId {
    if (id.contains('_')) {
      final parts = id.split('_');
      if (parts.length >= 2) {
        final lastPart = parts.last;
        if (lastPart.contains('T') && lastPart.contains(':')) {
          return parts.sublist(0, parts.length - 1).join('_');
        }
      }
    }
    return id;
  }

  static const categoryLabels = {
    'WORK': '업무',
    'PERSONAL': '개인',
    'FAMILY': '가족',
    'HEALTH': '건강',
    'SOCIAL': '소셜',
    'FINANCE': '재정',
    'OTHER': '기타',
  };

  static const categoryColors = {
    'WORK': 0xFF4A90D9,
    'PERSONAL': 0xFF50C878,
    'FAMILY': 0xFFFF6B6B,
    'HEALTH': 0xFFFFB347,
    'SOCIAL': 0xFF9B59B6,
    'FINANCE': 0xFF1ABC9C,
    'OTHER': 0xFF95A5A6,
  };

  static const recurrenceLabels = {
    'NONE': '없음',
    'DAILY': '매일',
    'WEEKLY': '매주',
    'MONTHLY': '매월',
    'YEARLY': '매년',
  };

  String get categoryLabel => categoryLabels[category] ?? '기타';
  int get categoryColorValue => categoryColors[category] ?? 0xFF95A5A6;
  String get recurrenceLabel => recurrenceLabels[recurrenceType] ?? '없음';
}
