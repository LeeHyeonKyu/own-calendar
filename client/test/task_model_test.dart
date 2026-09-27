import 'package:flutter_test/flutter_test.dart';
import 'package:own_calendar/models/task.dart';

/// Minimal valid JSON for TaskModel.fromJson — only the required fields.
Map<String, dynamic> _minimalJson({
  String? id,
  String? title,
  String? calendarId,
  Map<String, dynamic>? overrides,
}) {
  final json = <String, dynamic>{
    'id': id ?? 'task-1',
    'title': title ?? 'Test Task',
    'calendarId': calendarId ?? 'cal-1',
  };
  if (overrides != null) json.addAll(overrides);
  return json;
}

void main() {
  group('TaskModel.fromJson', () {
    test('test_30_default_status_fallback', () {
      // Given a JSON map with NO 'status' key
      final json = _minimalJson();
      expect(json.containsKey('status'), isFalse,
          reason: 'precondition: status key must be absent');

      // When parsing
      final task = TaskModel.fromJson(json);

      // Then the default status is 'TODO'
      expect(task.status, equals('TODO'));
    });

    test('test_30_explicit_status_preserved', () {
      // Given a JSON map with an explicit status
      final json = _minimalJson(overrides: {'status': 'DONE'});

      final task = TaskModel.fromJson(json);

      expect(task.status, equals('DONE'));
    });

    test('test_30_fromJson_required_fields', () {
      final json = _minimalJson(
        id: 'abc-123',
        title: 'Buy groceries',
        calendarId: 'cal-work',
      );

      final task = TaskModel.fromJson(json);

      expect(task.id, equals('abc-123'));
      expect(task.title, equals('Buy groceries'));
      expect(task.calendarId, equals('cal-work'));
    });

    test('test_30_fromJson_nullable_fields_default_to_null', () {
      final json = _minimalJson();

      final task = TaskModel.fromJson(json);

      expect(task.description, isNull);
      expect(task.dueDate, isNull);
      expect(task.scheduledDate, isNull);
      expect(task.scheduledTime, isNull);
      expect(task.completedAt, isNull);
      expect(task.eventId, isNull);
      expect(task.location, isNull);
      expect(task.notes, isNull);
      expect(task.rrule, isNull);
    });

    test('test_30_fromJson_defaults_for_non_nullable_fields', () {
      final json = _minimalJson();

      final task = TaskModel.fromJson(json);

      expect(task.priority, equals('NONE'));
      expect(task.recurrenceType, equals('NONE'));
      expect(task.sortOrder, equals(0));
      expect(task.attendees, isEmpty);
      expect(task.metaInherited, isFalse);
    });

    test('test_30_fromJson_nested_calendar_fields', () {
      final json = _minimalJson(overrides: {
        'calendar': {'name': 'Work', 'color': '#FF0000'},
      });

      final task = TaskModel.fromJson(json);

      expect(task.calendarName, equals('Work'));
      expect(task.calendarColor, equals('#FF0000'));
    });

    test('test_30_fromJson_nested_category_fields', () {
      final json = _minimalJson(overrides: {
        'categoryId': 'cat-1',
        'categoryRef': {
          'name': 'Meeting',
          'color': '#00FF00',
          'emoji': '📅',
        },
      });

      final task = TaskModel.fromJson(json);

      expect(task.categoryId, equals('cat-1'));
      expect(task.categoryName, equals('Meeting'));
      expect(task.categoryColor, equals('#00FF00'));
    });
  });

  group('TaskModel status helpers', () {
    test('test_30_status_helpers', () {
      // isTodo: true for TODO, false for others
      final todoTask = TaskModel.fromJson(
        _minimalJson(overrides: {'status': 'TODO'}),
      );
      expect(todoTask.isTodo, isTrue);
      expect(todoTask.isDone, isFalse);
      expect(todoTask.isCancelled, isFalse);

      final doneTask = TaskModel.fromJson(
        _minimalJson(overrides: {'status': 'DONE'}),
      );
      expect(doneTask.isTodo, isFalse);
      expect(doneTask.isDone, isTrue);
      expect(doneTask.isCancelled, isFalse);

      final cancelledTask = TaskModel.fromJson(
        _minimalJson(overrides: {'status': 'CANCELLED'}),
      );
      expect(cancelledTask.isTodo, isFalse);
      expect(cancelledTask.isDone, isFalse);
      expect(cancelledTask.isCancelled, isTrue);

      // statusLabel matches statusLabels for each known status
      for (final entry in TaskModel.statusLabels.entries) {
        final task = TaskModel.fromJson(
          _minimalJson(overrides: {'status': entry.key}),
        );
        expect(task.statusLabel, equals(entry.value),
            reason: 'statusLabel for ${entry.key} should be ${entry.value}');
      }
    });

    test('test_30_statusLabel_unknown_status_falls_back', () {
      // An unrecognized status falls back to the default label
      final task = TaskModel.fromJson(
        _minimalJson(overrides: {'status': 'UNKNOWN_STATUS'}),
      );
      expect(task.statusLabel, equals('할 일'));
    });
  });
}
