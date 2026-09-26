import 'package:flutter_test/flutter_test.dart';
import 'package:own_calendar/models/event.dart';

/// Builds a realistic API-style JSON map for EventModel.fromJson.
///
/// All timestamp strings intentionally omit the Z/offset suffix so that
/// DateTime.parse returns a local DateTime and the subsequent .toLocal()
/// in EventModel.fromJson is a no-op — assertions are timezone-independent.
Map<String, dynamic> _fixture({
  String id = 'evt-001',
  String title = 'Test event',
  String? description,
  String startTime = '2026-09-27T10:00:00',
  String endTime = '2026-09-27T11:00:00',
  bool isAllDay = false,
  bool isPrivate = false,
  String category = 'PERSONAL',
  List<String>? tags,
  String recurrenceType = 'NONE',
  String? recurrenceEnd,
  String? rrule,
  String calendarId = 'cal-001',
  Map<String, dynamic>? calendar,
  String? location,
  String? notes,
  List<Map<String, dynamic>>? attendees,
  int? reminderMinutes,
  String? categoryId,
  Map<String, dynamic>? categoryRef,
}) {
  return <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'startTime': startTime,
    'endTime': endTime,
    'isAllDay': isAllDay,
    'isPrivate': isPrivate,
    'category': category,
    'tags': tags,
    'recurrenceType': recurrenceType,
    'recurrenceEnd': recurrenceEnd,
    'rrule': rrule,
    'calendarId': calendarId,
    'calendar': calendar,
    'location': location,
    'notes': notes,
    'attendees': attendees,
    'reminderMinutes': reminderMinutes,
    'categoryId': categoryId,
    'categoryRef': categoryRef,
  };
}

void main() {
  group('test_29_fromJson', () {
    test('deserializes a full API response with nested calendar and categoryRef',
        () {
      final json = _fixture(
        id: 'evt-full-001',
        title: 'Sprint review',
        description: 'Demo and retro',
        startTime: '2026-09-27T14:00:00',
        endTime: '2026-09-27T15:30:00',
        isAllDay: false,
        isPrivate: true,
        category: 'WORK',
        tags: ['sprint', 'review'],
        recurrenceType: 'WEEKLY',
        rrule: 'RRULE:FREQ=WEEKLY;BYDAY=FR',
        calendarId: 'cal-work',
        calendar: {'name': 'Work Calendar', 'color': '#4A90D9'},
        location: 'Conference Room B',
        notes: 'Bring laptop',
        attendees: [
          {'userId': 'u1', 'name': 'Alice'},
          {'userId': 'u2', 'name': 'Bob'},
        ],
        reminderMinutes: 15,
        categoryId: 'cat-work',
        categoryRef: {'name': 'Work', 'color': '#4A90D9', 'emoji': 'W'},
      );

      final event = EventModel.fromJson(json);

      expect(event.id, 'evt-full-001');
      expect(event.title, 'Sprint review');
      expect(event.description, 'Demo and retro');
      // DateTime assertions use the same parse-then-toLocal path as production
      // code, ensuring timezone independence (dw4).
      expect(event.startTime, DateTime.parse('2026-09-27T14:00:00').toLocal());
      expect(event.endTime, DateTime.parse('2026-09-27T15:30:00').toLocal());
      expect(event.isAllDay, false);
      expect(event.isPrivate, true);
      expect(event.category, 'WORK');
      expect(event.tags, ['sprint', 'review']);
      expect(event.recurrenceType, 'WEEKLY');
      expect(event.rrule, 'RRULE:FREQ=WEEKLY;BYDAY=FR');
      expect(event.calendarId, 'cal-work');
      expect(event.calendarName, 'Work Calendar');
      expect(event.calendarColor, '#4A90D9');
      expect(event.location, 'Conference Room B');
      expect(event.notes, 'Bring laptop');
      expect(event.attendees, hasLength(2));
      expect(event.attendees[0]['name'], 'Alice');
      expect(event.attendees[1]['userId'], 'u2');
      expect(event.reminderMinutes, 15);
      expect(event.categoryId, 'cat-work');
      expect(event.categoryName, 'Work');
      expect(event.categoryColor, '#4A90D9');
      expect(event.categoryEmoji, 'W');
    });

    test('applies defaults for missing optional fields', () {
      final json = <String, dynamic>{
        'id': 'evt-minimal',
        'title': 'Quick note',
        'startTime': '2026-09-27T09:00:00',
        'endTime': '2026-09-27T09:30:00',
        'calendarId': 'cal-001',
      };

      final event = EventModel.fromJson(json);

      expect(event.id, 'evt-minimal');
      expect(event.title, 'Quick note');
      expect(event.description, isNull);
      expect(event.isAllDay, false);
      expect(event.isPrivate, false);
      expect(event.category, 'PERSONAL');
      expect(event.tags, isEmpty);
      expect(event.recurrenceType, 'NONE');
      expect(event.recurrenceEnd, isNull);
      expect(event.rrule, isNull);
      expect(event.calendarName, isNull);
      expect(event.calendarColor, isNull);
      expect(event.location, isNull);
      expect(event.notes, isNull);
      expect(event.attendees, isEmpty);
      expect(event.reminderMinutes, isNull);
      expect(event.categoryId, isNull);
      expect(event.categoryName, isNull);
      expect(event.categoryColor, isNull);
      expect(event.categoryEmoji, isNull);
    });
  });

  group('test_29_virtual_instance_id', () {
    test('composite id is recognized as virtual instance', () {
      final json = _fixture(id: 'abc123_2026-09-27T10:00:00');

      final event = EventModel.fromJson(json);

      expect(event.isVirtualInstance, true);
      expect(event.baseId, 'abc123');
      expect(event.instanceDateString, '2026-09-27T10:00:00');
    });

    test('plain id is not a virtual instance', () {
      final json = _fixture(id: 'evt-plain-001');

      final event = EventModel.fromJson(json);

      expect(event.isVirtualInstance, false);
      expect(event.baseId, 'evt-plain-001');
      expect(event.instanceDateString, isNull);
    });

    test('id with underscores but no ISO datetime suffix is not virtual', () {
      final json = _fixture(id: 'group_alpha_meeting');

      final event = EventModel.fromJson(json);

      // 'meeting' does not contain both T and : so it is not a datetime suffix
      expect(event.isVirtualInstance, false);
      expect(event.baseId, 'group_alpha_meeting');
      expect(event.instanceDateString, isNull);
    });

    test('composite id with underscores in master id preserves full baseId',
        () {
      final json = _fixture(id: 'team_alpha_evt001_2026-09-27T10:00:00');

      final event = EventModel.fromJson(json);

      expect(event.isVirtualInstance, true);
      expect(event.baseId, 'team_alpha_evt001');
      expect(event.instanceDateString, '2026-09-27T10:00:00');
    });
  });

  group('test_29_isRecurring', () {
    test('returns true when rrule is set', () {
      final json = _fixture(rrule: 'RRULE:FREQ=DAILY');

      final event = EventModel.fromJson(json);

      expect(event.isRecurring, true);
    });

    test('returns true when legacy recurrenceType is not NONE', () {
      final json = _fixture(recurrenceType: 'WEEKLY');

      final event = EventModel.fromJson(json);

      expect(event.isRecurring, true);
    });

    test('returns false when rrule is null and recurrenceType is NONE', () {
      final json = _fixture();

      final event = EventModel.fromJson(json);

      expect(event.isRecurring, false);
    });
  });

  group('test_29_category_fallback', () {
    test('categoryLabel returns Korean label for a known category', () {
      final json = _fixture(category: 'HEALTH');

      final event = EventModel.fromJson(json);

      expect(event.categoryLabel, equals('건강'));
    });

    test('categoryLabel falls back to 기타 for an unknown category', () {
      final json = _fixture(category: 'UNKNOWN_CATEGORY');

      final event = EventModel.fromJson(json);

      expect(event.categoryLabel, equals('기타'));
    });

    test('categoryColorValue falls back to OTHER color for an unknown category',
        () {
      final json = _fixture(category: 'UNKNOWN_CATEGORY');

      final event = EventModel.fromJson(json);

      // 0xFF95A5A6 is the color mapped to 'OTHER' in categoryColors
      expect(event.categoryColorValue, equals(0xFF95A5A6));
    });
  });

  group('test_29_recurrenceEnd', () {
    test('parses recurrenceEnd when present in JSON', () {
      final json = _fixture(recurrenceEnd: '2026-12-31T23:59:00');
      final event = EventModel.fromJson(json);

      expect(event.recurrenceEnd, isNotNull);
      expect(
          event.recurrenceEnd,
          equals(DateTime.parse('2026-12-31T23:59:00').toLocal()));
    });

    test('recurrenceEnd is null when not provided', () {
      final json = _fixture();
      final event = EventModel.fromJson(json);

      expect(event.recurrenceEnd, isNull);
    });
  });

  group('test_29_recurrenceLabel', () {
    test('returns Korean label for DAILY', () {
      final json = _fixture(recurrenceType: 'DAILY');
      final event = EventModel.fromJson(json);

      expect(event.recurrenceLabel, equals('매일'));
    });

    test('returns Korean label for YEARLY', () {
      final json = _fixture(recurrenceType: 'YEARLY');
      final event = EventModel.fromJson(json);

      expect(event.recurrenceLabel, equals('매년'));
    });

    test('falls back to 없음 for unknown recurrence type', () {
      final json = _fixture(recurrenceType: 'BIWEEKLY');
      final event = EventModel.fromJson(json);

      expect(event.recurrenceLabel, equals('없음'));
    });
  });

  group('test_29_rruleSummary', () {
    test('returns 매일 for RRULE:FREQ=DAILY', () {
      final json = _fixture(rrule: 'RRULE:FREQ=DAILY');
      final event = EventModel.fromJson(json);

      expect(event.rruleSummary, equals('매일'));
    });

    test('returns 반복 없음 when no rrule and recurrenceType is NONE', () {
      final json = _fixture();
      final event = EventModel.fromJson(json);

      expect(event.rruleSummary, equals('반복 없음'));
    });

    test('falls back to legacy label when rrule is null but recurrenceType set',
        () {
      final json = _fixture(recurrenceType: 'WEEKLY');
      final event = EventModel.fromJson(json);

      expect(event.rruleSummary, equals('매주'));
    });

    test('returns weekly summary with day names for BYDAY rule', () {
      final json = _fixture(rrule: 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR');
      final event = EventModel.fromJson(json);

      expect(event.rruleSummary, equals('매주 월, 수, 금요일'));
    });
  });
}
