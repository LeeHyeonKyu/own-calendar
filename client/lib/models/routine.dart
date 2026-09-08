class RoutineGroupModel {
  final String id;
  final String name;
  final int sortOrder;

  RoutineGroupModel({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  factory RoutineGroupModel.fromJson(Map<String, dynamic> json) {
    return RoutineGroupModel(
      id: json['id'],
      name: json['name'],
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

class RoutineModel {
  final String id;
  final String name;
  final String? time; // "HH:mm"
  final List<int> repeatDays; // 0=Sunday, 1=Monday, ..., 6=Saturday
  final String? groupId;
  final String? groupName;
  final int sortOrder;
  final bool completed;
  final DateTime? completedAt;

  RoutineModel({
    required this.id,
    required this.name,
    this.time,
    required this.repeatDays,
    this.groupId,
    this.groupName,
    this.sortOrder = 0,
    this.completed = false,
    this.completedAt,
  });

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
    return RoutineModel(
      id: json['id'],
      name: json['name'],
      time: json['time'],
      repeatDays: (json['repeatDays'] as List).map((e) => e as int).toList(),
      groupId: json['groupId'] ?? json['group']?['id'],
      groupName: json['group']?['name'],
      sortOrder: json['sortOrder'] ?? 0,
      completed: json['completed'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }

  bool get hasTime => time != null;

  String get repeatDaysLabel {
    if (repeatDays.length == 7) return '매일';
    // Check weekdays (Mon-Fri = 1,2,3,4,5)
    final weekdays = {1, 2, 3, 4, 5};
    if (repeatDays.toSet().containsAll(weekdays) && repeatDays.length == 5) {
      return '평일';
    }
    // Check weekends (Sat=6, Sun=0)
    final weekends = {0, 6};
    if (repeatDays.toSet().containsAll(weekends) && repeatDays.length == 2) {
      return '주말';
    }
    return repeatDays.map((d) => _dayLabels[d]).join(', ');
  }

  static const _dayLabels = ['일', '월', '화', '수', '목', '금', '토'];
  static const dayLabelsKo = ['일', '월', '화', '수', '목', '금', '토'];
}
