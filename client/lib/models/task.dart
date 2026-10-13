import 'package:uuid/uuid.dart';
import '../utils/rrule_utils.dart' as rrule_utils;

const _uuid = Uuid();

class ChecklistItem {
  final String id;
  String text;
  bool checked;
  List<ChecklistItem> children;

  ChecklistItem({
    String? id,
    required this.text,
    this.checked = false,
    List<ChecklistItem>? children,
  })  : id = id ?? _uuid.v4(),
        children = children ?? [];

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      checked: json['checked'] as bool? ?? false,
      children: (json['children'] as List<dynamic>?)
              ?.map((c) => ChecklistItem.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'checked': checked,
        'children': children.map((c) => c.toJson()).toList(),
      };

  ChecklistItem copyWith({
    String? id,
    String? text,
    bool? checked,
    List<ChecklistItem>? children,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      checked: checked ?? this.checked,
      children: children ?? this.children.map((c) => c.copyWith()).toList(),
    );
  }

  /// Count all items (self + descendants).
  int get totalCount => 1 + children.fold(0, (sum, c) => sum + c.totalCount);

  /// Count checked items (self + descendants).
  int get checkedCount =>
      (checked ? 1 : 0) + children.fold(0, (sum, c) => sum + c.checkedCount);
}

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
  final String? rrule;
  final DateTime? completedAt;
  final String? eventId;
  final String calendarId;
  final String? calendarName;
  final String? calendarColor;
  final String? eventTitle;
  final int sortOrder;
  final String? location;
  final String? notes;
  final List<Map<String, dynamic>> attendees;
  final bool metaInherited;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryEmoji;
  final List<ChecklistItem>? checklist;

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
    this.rrule,
    this.completedAt,
    this.eventId,
    required this.calendarId,
    this.calendarName,
    this.calendarColor,
    this.eventTitle,
    this.sortOrder = 0,
    this.location,
    this.notes,
    this.attendees = const [],
    this.metaInherited = false,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.categoryEmoji,
    this.checklist,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'] ?? 'TODO',
      priority: json['priority'] ?? 'NONE',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']).toLocal() : null,
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate']).toLocal()
          : null,
      scheduledTime: json['scheduledTime'],
      recurrenceType: json['recurrenceType'] ?? 'NONE',
      recurrenceEnd: json['recurrenceEnd'] != null
          ? DateTime.parse(json['recurrenceEnd']).toLocal()
          : null,
      rrule: json['rrule'],
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt']).toLocal()
          : null,
      eventId: json['eventId'],
      calendarId: json['calendarId'],
      calendarName: json['calendar']?['name'],
      calendarColor: json['calendar']?['color'],
      eventTitle: json['event']?['title'],
      sortOrder: json['sortOrder'] ?? 0,
      location: json['location'],
      notes: json['notes'],
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          [],
      metaInherited: json['metaInherited'] ?? false,
      categoryId: json['categoryId'],
      categoryName: json['categoryRef']?['name'],
      categoryColor: json['categoryRef']?['color'],
      categoryEmoji: json['categoryRef']?['emoji'],
      checklist: (json['checklist'] as List<dynamic>?)
          ?.map((c) => ChecklistItem.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }

  bool get isDone => status == 'DONE';
  bool get isCancelled => status == 'CANCELLED';
  bool get isTodo => status == 'TODO';
  bool get hasEvent => eventId != null;
  bool get hasChecklist => checklist != null && checklist!.isNotEmpty;
  bool get hasTime => scheduledTime != null;
  bool get hasDueDate => dueDate != null;
  bool get isRecurring => rrule != null || recurrenceType != 'NONE';

  /// True when this instance's id is a virtual composite id
  /// (`${masterId}_${instanceDate.toISOString()}`) rather than the master id.
  bool get isVirtualInstance => id != baseId;

  /// The ISO date string embedded in a virtual composite id, or null when
  /// this is not a virtual instance. Used as the `instanceDate` query param
  /// when editing/deleting a single occurrence of a recurring task.
  String? get instanceDateString =>
      isVirtualInstance ? id.substring(baseId.length + 1) : null;

  /// Human-readable Korean summary of the recurrence rule, falling back to
  /// the legacy recurrenceType/recurrenceEnd fields when no rrule is set.
  String get rruleSummary => rrule_utils.rruleSummaryText(
        rrule,
        legacyType: recurrenceType,
        legacyEnd: recurrenceEnd,
      );

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

  /// Common RRULE presets keyed by a short id.
  static const rrulePresets = rrule_utils.rrulePresets;

  /// Total number of checklist items (all levels).
  int get checklistTotal =>
      checklist?.fold<int>(0, (sum, item) => sum + item.totalCount) ?? 0;

  /// Number of checked checklist items (all levels).
  int get checklistChecked =>
      checklist?.fold<int>(0, (sum, item) => sum + item.checkedCount) ?? 0;

  String get statusLabel => statusLabels[status] ?? '할 일';
  String get priorityLabel => priorityLabels[priority] ?? '없음';
  int get priorityColorValue => priorityColors[priority] ?? 0xFF8B95A8;
  String get recurrenceLabel => recurrenceLabels[recurrenceType] ?? '없음';
}
