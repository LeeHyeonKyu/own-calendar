class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final String recurrenceType;
  final DateTime? recurrenceEnd;
  final DateTime? completedAt;
  final String? location;
  final String? notes;
  final List<Map<String, dynamic>> attendees;
  final bool metaInherited;
  final String? eventId;
  final String calendarId;
  final String? calendarName;
  final String? calendarColor;
  final String? eventTitle;
  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.status = 'TODO',
    this.priority = 'NONE',
    this.dueDate,
    this.scheduledDate,
    this.scheduledTime,
    this.recurrenceType = 'NONE',
    this.recurrenceEnd,
    this.completedAt,
    this.location,
    this.notes,
    this.attendees = const [],
    this.metaInherited = false,
    this.eventId,
    required this.calendarId,
    this.calendarName,
    this.calendarColor,
    this.eventTitle,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'] ?? 'TODO',
      priority: json['priority'] ?? 'NONE',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'])
          : null,
      scheduledTime: json['scheduledTime'],
      recurrenceType: json['recurrenceType'] ?? 'NONE',
      recurrenceEnd: json['recurrenceEnd'] != null
          ? DateTime.parse(json['recurrenceEnd'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      location: json['location'],
      notes: json['notes'],
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          [],
      metaInherited: json['metaInherited'] ?? false,
      eventId: json['eventId'],
      calendarId: json['calendarId'],
      calendarName: json['calendar']?['name'],
      calendarColor: json['calendar']?['color'],
      eventTitle: json['event']?['title'],
    );
  }

  bool get hasMetadata =>
      (location != null && location!.isNotEmpty) ||
      (notes != null && notes!.isNotEmpty) ||
      attendees.isNotEmpty;

  bool get isDone => status == 'DONE';
  bool get isCancelled => status == 'CANCELLED';
  bool get isTodo => status == 'TODO';
  bool get hasEvent => eventId != null;
  bool get hasTime => scheduledTime != null;
  bool get hasDueDate => dueDate != null;
  bool get isRecurring => recurrenceType != 'NONE';

  bool get isOverdue {
    if (isDone || isCancelled || dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

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

  static const statusLabels = {
    'TODO': '할 일',
    'DONE': '완료',
    'CANCELLED': '취소',
  };

  static const priorityLabels = {
    'HIGH': '높음',
    'MEDIUM': '보통',
    'LOW': '낮음',
    'NONE': '없음',
  };

  static const priorityColors = {
    'HIGH': 0xFFEF6B6B,
    'MEDIUM': 0xFFF0A050,
    'LOW': 0xFF4ADE80,
    'NONE': 0xFF8B95A8,
  };

  static const recurrenceLabels = {
    'NONE': '없음',
    'DAILY': '매일',
    'WEEKLY': '매주',
    'MONTHLY': '매월',
    'YEARLY': '매년',
  };

  String get statusLabel => statusLabels[status] ?? '할 일';
  String get priorityLabel => priorityLabels[priority] ?? '없음';
  int get priorityColorValue => priorityColors[priority] ?? 0xFF8B95A8;
  String get recurrenceLabel => recurrenceLabels[recurrenceType] ?? '없음';
}
