class EventInviteModel {
  final String id;
  final String status; // PENDING, ACCEPTED, DECLINED
  final DateTime createdAt;
  final InviteEvent? event;
  final InviteUser? invitee;

  EventInviteModel({
    required this.id,
    required this.status,
    required this.createdAt,
    this.event,
    this.invitee,
  });

  factory EventInviteModel.fromJson(Map<String, dynamic> json) {
    return EventInviteModel(
      id: json['id'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      event: json['event'] != null ? InviteEvent.fromJson(json['event']) : null,
      invitee: json['invitee'] != null
          ? InviteUser.fromJson(json['invitee'])
          : null,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isDeclined => status == 'DECLINED';

  static const statusLabels = {
    'PENDING': '대기 중',
    'ACCEPTED': '수락',
    'DECLINED': '거절',
  };

  String get statusLabel => statusLabels[status] ?? status;
}

class InviteEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final InviteUser? createdBy;

  InviteEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.createdBy,
  });

  factory InviteEvent.fromJson(Map<String, dynamic> json) {
    return InviteEvent(
      id: json['id'],
      title: json['title'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      isAllDay: json['isAllDay'] ?? false,
      createdBy: json['createdBy'] != null
          ? InviteUser.fromJson(json['createdBy'])
          : null,
    );
  }
}

class InviteUser {
  final String id;
  final String name;
  final String? email;

  InviteUser({
    required this.id,
    required this.name,
    this.email,
  });

  factory InviteUser.fromJson(Map<String, dynamic> json) {
    return InviteUser(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}
