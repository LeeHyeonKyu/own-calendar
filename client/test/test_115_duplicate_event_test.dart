import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:own_calendar/models/event.dart';
import 'package:own_calendar/providers/calendar_provider.dart';
import 'package:own_calendar/screens/event_form_screen.dart';
import 'package:own_calendar/services/api_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [ApiService] for widget tests. Tracks POST/PUT calls separately.
class _FakeApiService implements ApiService {
  _FakeApiService({this.events = const [], this.calendars = const []});

  List<Map<String, dynamic>> events;
  List<Map<String, dynamic>> calendars;
  final List<String> postPaths = [];
  final List<Map<String, dynamic>> postBodies = [];
  final List<String> putPaths = [];
  final List<Map<String, dynamic>> putBodies = [];

  @override
  Future<http.Response> get(String path) async {
    if (path.startsWith('/events')) {
      return http.Response(jsonEncode(events), 200);
    }
    if (path.startsWith('/calendars')) {
      return http.Response(jsonEncode(calendars), 200);
    }
    return http.Response('', 404);
  }

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    postPaths.add(path);
    postBodies.add(Map.from(body));
    return http.Response(jsonEncode({'id': 'new-evt-id', ...body}), 201);
  }

  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    putPaths.add(path);
    putBodies.add(Map.from(body));
    return http.Response(jsonEncode(body), 200);
  }

  @override
  Future<http.Response> delete(String path) async =>
      http.Response('', 204);

  @override
  Future<http.Response> patch(String path,
          [Map<String, dynamic>? body]) async =>
      http.Response('{}', 200);

  @override
  Future<String?> get accessToken async => 'fake';
  @override
  Future<String?> get refreshToken async => 'fake';
  @override
  Future<String?> get cachedUserJson async => null;
  @override
  Future<void> saveTokens(String a, String r) async {}
  @override
  Future<void> saveCachedUser(String userJson) async {}
  @override
  Future<void> clearTokens() async {}
}

/// Testable [CalendarProvider] that suppresses HomeWidget platform calls.
class _TestableCalendarProvider extends CalendarProvider {
  _TestableCalendarProvider({required ApiService api}) : super(api: api);

  @override
  void triggerWidgetUpdates() {
    // No-op: HomeWidget not available in tests.
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a GoRouter-based widget tree with both /event/new and /event/:id/edit
/// routes, mirroring production routing for duplicate-action navigation.
Widget _buildApp({
  required _TestableCalendarProvider provider,
  required void Function(GoRouter router) onBuild,
}) {
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
      GoRoute(
        path: '/event/new',
        builder: (ctx, state) {
          final extra = state.extra;
          if (extra is EventModel) {
            return EventFormScreen(template: extra);
          }
          DateTime? date;
          if (extra is DateTime) {
            date = extra;
          } else {
            final dateStr = state.uri.queryParameters['date'];
            date = dateStr != null ? DateTime.tryParse(dateStr) : null;
          }
          return EventFormScreen(initialDate: date);
        },
      ),
      GoRoute(
        path: '/event/:id/edit',
        builder: (ctx, state) => EventFormScreen(
          eventId: state.pathParameters['id'],
        ),
      ),
    ],
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    onBuild(router);
  });

  return ChangeNotifierProvider<CalendarProvider>.value(
    value: provider,
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

/// Scrolls the first [Scrollable] down until [finder] is visible.
Future<void> _scrollToVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _calendar = {
  'id': 'cal-1',
  'name': 'My Calendar',
  'color': '#4A90D9',
  'isDefault': true,
  'visibility': 'PUBLIC',
  'type': 'PERSONAL',
};

Map<String, dynamic> _singleEvent() => {
      'id': 'evt-1',
      'title': 'Team Meeting',
      'description': 'Weekly sync',
      'startTime': '2026-10-01T10:00:00.000Z',
      'endTime': '2026-10-01T11:00:00.000Z',
      'isAllDay': false,
      'isPrivate': true,
      'category': 'WORK',
      'calendarId': 'cal-1',
      'reminderMinutes': 15,
      'categoryId': 'cat-1',
      'recurrenceType': 'NONE',
      'tags': <dynamic>[],
    };

Map<String, dynamic> _recurringInstanceEvent() => {
      // Virtual instance id: masterId + instance date
      'id': 'evt-rec_2026-10-01T10:00:00.000Z',
      'title': 'Weekly Standup',
      'description': 'Daily check-in',
      'startTime': '2026-10-01T10:00:00.000Z',
      'endTime': '2026-10-01T10:30:00.000Z',
      'isAllDay': false,
      'isPrivate': false,
      'category': 'WORK',
      'calendarId': 'cal-1',
      'recurrenceType': 'WEEKLY',
      'rrule': 'FREQ=WEEKLY;BYDAY=TH',
      'tags': <dynamic>[],
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Duplicate event (#115)', () {
    // dw1: Tapping the duplicate icon opens a pre-filled new-event form.
    testWidgets(
        'test_115_duplicate_opens_prefilled_new_form',
        (tester) async {
      final fake = _FakeApiService(
        events: [_singleEvent()],
        calendars: [_calendar],
      );
      final provider = _TestableCalendarProvider(api: fake);
      await provider.loadEvents();

      await tester.pumpWidget(_buildApp(
        provider: provider,
        onBuild: (router) {
          router.push('/event/evt-1/edit');
        },
      ));
      await tester.pumpAndSettle();

      // Precondition: edit form loaded with event title
      expect(find.text('Team Meeting'), findsOneWidget,
          reason: 'precondition: event form loaded with title');
      expect(find.text('일정 수정'), findsOneWidget,
          reason: 'precondition: AppBar shows edit title');

      // The duplicate (copy) icon must exist in edit-mode AppBar
      expect(find.byIcon(Icons.copy), findsOneWidget,
          reason: 'edit-mode AppBar must have a copy/duplicate icon');

      // Tap the duplicate icon
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();

      // After duplicate: AppBar title must be "새 일정" (new event)
      expect(find.text('새 일정'), findsOneWidget,
          reason:
              'after duplicate, AppBar title must be "새 일정" (new event)');

      // Title field must still show the original event title
      expect(find.text('Team Meeting'), findsOneWidget,
          reason: 'duplicated form must pre-fill the title');

      // Edit-only icons (delete, copy) must NOT appear in new-event mode
      expect(find.byIcon(Icons.delete), findsNothing,
          reason: 'new-event form must not show delete icon');
      expect(find.byIcon(Icons.copy), findsNothing,
          reason: 'new-event form must not show copy/duplicate icon');

      // ── Pre-filled field assertions added in rework (spec1) ──
      // Description must be pre-filled
      expect(find.text('Weekly sync'), findsOneWidget,
          reason: 'duplicated form must pre-fill the description');

      // Category dropdown must show WORK label (업무, non-default PERSONAL)
      expect(find.text('업무'), findsAtLeastNWidgets(1),
          reason: 'duplicated form must pre-fill category to WORK (업무)');

      // Start/end dates must reflect the original event date
      expect(find.textContaining('2026-10-01'), findsAtLeastNWidgets(1),
          reason: 'duplicated form must show original event date');

      // Scroll to isPrivate switch (original=true, default=false)
      await _scrollToVisible(
          tester, find.widgetWithText(SwitchListTile, '비공개'));
      final privateTile = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, '비공개'));
      expect(privateTile.value, isTrue,
          reason:
              'duplicated form must pre-fill isPrivate to true (non-default)');

      // Reminder must show 15분 전 (original=15, default=10)
      await _scrollToVisible(tester, find.text('15분 전'));
      expect(find.text('15분 전'), findsOneWidget,
          reason:
              'duplicated form must pre-fill reminder to 15분 전 (non-default)');

      // Calendar dropdown must show the original calendar name
      await _scrollToVisible(tester, find.text('My Calendar'));
      expect(find.text('My Calendar'), findsAtLeastNWidgets(1),
          reason: 'duplicated form must pre-fill the calendar selection');
    });

    // dw2: Saving the duplicated form calls createEvent (POST), not updateEvent (PUT).
    testWidgets(
        'test_115_duplicate_save_creates_not_updates',
        (tester) async {
      final fake = _FakeApiService(
        events: [_singleEvent()],
        calendars: [_calendar],
      );
      final provider = _TestableCalendarProvider(api: fake);
      await provider.loadEvents();

      await tester.pumpWidget(_buildApp(
        provider: provider,
        onBuild: (router) {
          router.push('/event/evt-1/edit');
        },
      ));
      await tester.pumpAndSettle();

      // Tap the duplicate icon
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();

      // Precondition: now on new-event form
      expect(find.text('새 일정'), findsOneWidget,
          reason: 'precondition: on new-event form after duplicate');

      // Scroll to the save button and tap it
      final saveButton = find.text('저장');
      await _scrollToVisible(tester, saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // POST (createEvent) must have been called
      expect(fake.postPaths, hasLength(1),
          reason: 'createEvent (POST) must be called exactly once');
      expect(fake.postPaths.first, '/events',
          reason: 'POST must target /events');

      // PUT (updateEvent) must NOT have been called
      expect(fake.putPaths, isEmpty,
          reason: 'updateEvent (PUT) must not be called');

      // Payload must have the original title
      expect(fake.postBodies.first['title'], 'Team Meeting',
          reason: 'POST payload must carry the pre-filled title');

      // ── Full payload field assertions added in rework (spec2) ──
      final body = fake.postBodies.first;
      expect(body['description'], 'Weekly sync',
          reason: 'POST payload must carry the pre-filled description');
      expect(body['isPrivate'], isTrue,
          reason: 'POST payload must carry isPrivate=true');
      expect(body['category'], 'WORK',
          reason: 'POST payload must carry category WORK');
      expect(body['calendarId'], 'cal-1',
          reason: 'POST payload must carry the original calendarId');
      expect(body['reminderMinutes'], 15,
          reason: 'POST payload must carry reminderMinutes=15');
      expect(body['categoryId'], 'cat-1',
          reason: 'POST payload must carry the original categoryId');
      expect(body['isAllDay'], isFalse,
          reason: 'POST payload must carry isAllDay=false');
      expect(body['recurrenceType'], 'NONE',
          reason: 'POST payload must carry recurrenceType NONE');

      // Start/end times must round-trip to the original UTC values
      final postedStart = DateTime.parse(body['startTime'] as String);
      final postedEnd = DateTime.parse(body['endTime'] as String);
      expect(postedStart, DateTime.utc(2026, 10, 1, 10, 0),
          reason: 'POST startTime must match original event start');
      expect(postedEnd, DateTime.utc(2026, 10, 1, 11, 0),
          reason: 'POST endTime must match original event end');
    });

    // dw3: Duplicating a recurring instance produces a single (non-recurring) event.
    testWidgets(
        'test_115_duplicate_of_recurring_instance_is_single',
        (tester) async {
      final fake = _FakeApiService(
        events: [_recurringInstanceEvent()],
        calendars: [_calendar],
      );
      final provider = _TestableCalendarProvider(api: fake);
      await provider.loadEvents();

      await tester.pumpWidget(_buildApp(
        provider: provider,
        onBuild: (router) {
          router.push(
              '/event/evt-rec_2026-10-01T10:00:00.000Z/edit');
        },
      ));
      await tester.pumpAndSettle();

      // Precondition: recurring instance form loaded
      expect(find.text('Weekly Standup'), findsOneWidget,
          reason: 'precondition: recurring instance form loaded');

      // Tap the duplicate icon
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();

      // Scroll to and tap save on the duplicated form
      final saveButton = find.text('저장');
      await _scrollToVisible(tester, saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify POST was called
      expect(fake.postPaths, hasLength(1),
          reason: 'createEvent (POST) must be called');

      final body = fake.postBodies.first;

      // Recurrence must be stripped
      expect(body['recurrenceType'], 'NONE',
          reason:
              'duplicated recurring instance must have recurrenceType NONE');
      expect(body['rrule'], isNull,
          reason: 'duplicated recurring instance must have null rrule');

      // Start/end must match the instance (not some default)
      final startTime = DateTime.parse(body['startTime'] as String);
      final endTime = DateTime.parse(body['endTime'] as String);
      expect(startTime, DateTime.utc(2026, 10, 1, 10, 0),
          reason: 'start time must match the instance start');
      expect(endTime, DateTime.utc(2026, 10, 1, 10, 30),
          reason: 'end time must match the instance end');
    });

    // dw4: Opening /event/new without a template shows the same empty form.
    testWidgets(
        'test_115_new_form_without_template_unchanged',
        (tester) async {
      final fake = _FakeApiService(
        events: [],
        calendars: [_calendar],
      );
      final provider = _TestableCalendarProvider(api: fake);

      await tester.pumpWidget(_buildApp(
        provider: provider,
        onBuild: (router) {
          router.push('/event/new');
        },
      ));
      await tester.pumpAndSettle();

      // AppBar title must be "새 일정"
      expect(find.text('새 일정'), findsOneWidget,
          reason: 'new-event form must show "새 일정" title');

      // No edit-mode icons
      expect(find.byIcon(Icons.delete), findsNothing,
          reason: 'new-event form must not show delete icon');
      expect(find.byIcon(Icons.copy), findsNothing,
          reason: 'new-event form must not show copy icon');

      // Title field must be empty (no pre-filled text from a template)
      expect(find.text('Team Meeting'), findsNothing,
          reason: 'empty form must not have any pre-filled title');
      expect(find.text('Weekly Standup'), findsNothing,
          reason: 'empty form must not have any pre-filled title');

      // Scroll to save button to verify it says "저장" (not "수정")
      final saveButton = find.text('저장');
      await _scrollToVisible(tester, saveButton);
      expect(saveButton, findsOneWidget,
          reason: 'save button must say "저장"');
    });

    // dw5: Tapping an empty time slot in weekly view still works after
    // /event/new route accepts extra as EventModel. weekly_view_screen.dart:447
    // passes extra: DateTime -- the router must not crash on it.
    testWidgets(
        'test_115_weekly_tap_new_event_unbroken',
        (tester) async {
      final fake = _FakeApiService(
        events: [],
        calendars: [_calendar],
      );
      final provider = _TestableCalendarProvider(api: fake);

      await tester.pumpWidget(_buildApp(
        provider: provider,
        onBuild: (router) {
          // Simulate weekly_view_screen.dart:447 -- passes DateTime as extra
          router.push('/event/new', extra: DateTime(2026, 10, 1, 14));
        },
      ));
      await tester.pumpAndSettle();

      // Must render without error -- EventFormScreen should display
      expect(find.text('새 일정'), findsOneWidget,
          reason:
              'EventFormScreen must render correctly when extra is DateTime');

      // No edit-mode icons (this is a new-event form)
      expect(find.byIcon(Icons.delete), findsNothing,
          reason: 'new-event form must not show delete icon');
      expect(find.byIcon(Icons.copy), findsNothing,
          reason: 'new-event form must not show copy icon');
    });
  });
}
