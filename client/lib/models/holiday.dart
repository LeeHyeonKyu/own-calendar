class HolidayModel {
  final String id;
  final String countryCode;
  final DateTime date;
  final String name;

  HolidayModel({
    required this.id,
    required this.countryCode,
    required this.date,
    required this.name,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    return HolidayModel(
      id: json['id'] as String,
      countryCode: json['countryCode'] as String,
      date: DateTime.parse(json['date'] as String).toLocal(),
      name: json['name'] as String,
    );
  }
}
