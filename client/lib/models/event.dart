import '../utils/rrule_utils.dart' as rrule_utils;

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
  final String? rrule;
  final String calendarId;
  final String? calendarName;
  final String? calendarColor;
  final String? location;
  final String? notes;
  final List<Map<String, dynamic>> attendees;
  final int? reminderMinutes;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryEmoji;

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
    this.rrule,
    required this.calendarId,
    this.calendarName,
    this.calendarColor,
    this.location,
    this.notes,
    this.attendees = const [],
    this.reminderMinutes,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.categoryEmoji,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['startTime']).toLocal(),
      endTime: DateTime.parse(json['endTime']).toLocal(),
      isAllDay: json['isAllDay'] ?? false,
      isPrivate: json['isPrivate'] ?? false,
      category: json['category'] ?? 'PERSONAL',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      recurrenceType: json['recurrenceType'] ?? 'NONE',
      recurrenceEnd: json['recurrenceEnd'] != null
          ? DateTime.parse(json['recurrenceEnd']).toLocal()
          : null,
      rrule: json['rrule'],
      calendarId: json['calendarId'],
      calendarName: json['calendar']?['name'],
      calendarColor: json['calendar']?['color'],
      location: json['location'],
      notes: json['notes'],
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          [],
      reminderMinutes: json['reminderMinutes'],
      categoryId: json['categoryId'],
      categoryName: json['categoryRef']?['name'],
      categoryColor: json['categoryRef']?['color'],
      categoryEmoji: json['categoryRef']?['emoji'],
    );
  }

  bool get isRecurring => rrule != null || recurrenceType != 'NONE';

  /// True when this instance's id is a virtual composite id
  /// (`${masterId}_${instanceDate.toISOString()}`) rather than the master id.
  bool get isVirtualInstance => id != baseId;

  /// The ISO date string embedded in a virtual composite id, or null when
  /// this is not a virtual instance. Used as the `instanceDate` query param
  /// when editing/deleting a single occurrence of a recurring event.
  String? get instanceDateString =>
      isVirtualInstance ? id.substring(baseId.length + 1) : null;

  /// Human-readable Korean summary of the recurrence rule, falling back to
  /// the legacy recurrenceType/recurrenceEnd fields when no rrule is set.
  String get rruleSummary => rrule_utils.rruleSummaryText(
        rrule,
        legacyType: recurrenceType,
        legacyEnd: recurrenceEnd,
      );

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

  /// Common RRULE presets keyed by a short id.
  static const rrulePresets = rrule_utils.rrulePresets;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  String get categoryLabel => categoryLabels[category] ?? '기타';
  int get categoryColorValue => categoryColors[category] ?? 0xFF95A5A6;
  String get recurrenceLabel => recurrenceLabels[recurrenceType] ?? '없음';
}
