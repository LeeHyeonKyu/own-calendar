import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:own_calendar/providers/calendar_provider.dart';
import 'package:own_calendar/screens/event_form_screen.dart';
import 'package:own_calendar/services/api_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [ApiService] for widget tests. Configurable events, tracks deletes.
class _FakeApiService implements ApiService {
  @override
  Future<String?> createWidgetKey() async => null;
  _FakeApiService({this.events = const [], this.calendars = const []});

  @override
  void Function()? onSessionExpired;

  List<Map<String, dynamic>> events;
  List<Map<String, dynamic>> calendars;
  final List<String> deletedPaths = [];

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
  Future<http.Response> delete(String path) async {
    deletedPaths.add(path);
    return http.Response('', 204);
  }

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

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async =>
      http.Response('{}', 201);
  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async =>
      http.Response('{}', 200);
  @override
  Future<http.Response> patch(String path,
          [Map<String, dynamic>? body]) async =>
      http.Response('{}', 200);
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

/// Builds a GoRouter-based widget tree so that `context.pop()` in the
/// EventFormScreen works correctly (it uses GoRouter's pop extension).
/// [onBuild] is called with the router once the tree is mounted, so the
/// test can navigate to the event form after the home route is established
/// (ensures pop has somewhere to go).
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
        path: '/event/:id/edit',
        builder: (ctx, state) => EventFormScreen(
          eventId: state.pathParameters['id'],
        ),
      ),
    ],
  );

  // Schedule the navigation after the first frame
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

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _calendar = {
  'id': 'cal-1',
  'name': 'My Calendar',
  'color': '#4A90D9',
};

Map<String, dynamic> _nonRecurringEvent() => {
      'id': 'evt-simple',
      'title': 'Simple Meeting',
      'startTime': '2026-10-01T10:00:00.000Z',
      'endTime': '2026-10-01T11:00:00.000Z',
      'isAllDay': false,
      'category': 'WORK',
      'calendarId': 'cal-1',
      'recurrenceType': 'NONE',
    };

Map<String, dynamic> _recurringInstanceEvent() => {
      // Virtual instance id: masterId + instance date
      'id': 'evt-rec_2026-10-01T10:00:00.000Z',
      'title': 'Weekly Standup',
      'startTime': '2026-10-01T10:00:00.000Z',
      'endTime': '2026-10-01T10:30:00.000Z',
      'isAllDay': false,
      'category': 'WORK',
      'calendarId': 'cal-1',
      'recurrenceType': 'WEEKLY',
      'rrule': 'FREQ=WEEKLY;BYDAY=TH',
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Delete UX (#114)', () {
    testWidgets(
        'test_114_no_confirm_dialog_snackbar_with_undo — '
        'non-recurring delete: no AlertDialog, form pops, SnackBar with undo',
        (tester) async {
      final fake = _FakeApiService(
        events: [_nonRecurringEvent()],
        calendars: [_calendar],
      );
      final provider = _TestableCalendarProvider(api: fake);

      // Pre-load events so EventFormScreen._loadEvent finds them
      await provider.loadEvents();

      await tester.pumpWidget(_buildApp(
        provider: provider,
        onBuild: (router) {
          // push (not go) so that '/' stays in the stack and pop works
          router.push('/event/evt-simple/edit');
        },
      ));
      // Pump to process postFrameCallback + navigation
      await tester.pumpAndSettle();

      // Precondition: the form should show the event title
      expect(find.text('Simple Meeting'), findsOneWidget,
          reason: 'precondition: event form loaded');

      // Tap the delete icon in the AppBar.
      // Use pump() not pumpAndSettle() -- deleteEventDeferred creates a
      // 5-second Timer which pumpAndSettle would wait to complete.
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump(); // process the tap
      await tester.pump(const Duration(milliseconds: 500)); // route transition + SnackBar

      // AlertDialog must NOT appear
      expect(find.byType(AlertDialog), findsNothing,
          reason:
              'non-recurring delete must NOT show a confirmation AlertDialog');

      // SnackBar with undo action must be visible
      expect(find.text('일정을 삭제했습니다'), findsOneWidget,
          reason: 'SnackBar message must appear after non-recurring delete');
      expect(find.text('실행 취소'), findsOneWidget,
          reason: 'SnackBar must have an undo action');

      // Clean up: dispose provider to cancel the deferred-delete timer, then
      // advance time past the SnackBar duration so no pending timers remain.
      provider.dispose();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets(
        'test_114_no_confirm_dialog_snackbar_with_undo — '
        'recurring instance delete: showDeleteModeDialog still appears',
        (tester) async {
      final fake = _FakeApiService(
        events: [_recurringInstanceEvent()],
        calendars: [_calendar],
      );
      final provider = _TestableCalendarProvider(api: fake);

      // Pre-load events
      await provider.loadEvents();

      // Use URI-encoded event id in the route path
      await tester.pumpWidget(_buildApp(
        provider: provider,
        onBuild: (router) {
          router.push('/event/evt-rec_2026-10-01T10:00:00.000Z/edit');
        },
      ));
      await tester.pumpAndSettle();

      // Precondition
      expect(find.text('Weekly Standup'), findsOneWidget,
          reason: 'precondition: recurring event form loaded');

      // Tap delete icon
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      // The recurring-instance delete dialog MUST appear
      expect(find.text('반복 일정 삭제'), findsOneWidget,
          reason:
              'recurring instance delete must show showDeleteModeDialog');
    });
  });
}
