import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:own_calendar/providers/calendar_provider.dart';
import 'package:own_calendar/services/api_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [ApiService] that records delete calls and returns configurable
/// responses for get/delete.
class _FakeApiService implements ApiService {
  @override
  Future<String?> createWidgetKey() async => null;
  _FakeApiService({this.events = const []});

  @override
  void Function()? onSessionExpired;

  /// Events the server "holds" -- returned by GET /events.
  List<Map<String, dynamic>> events;

  /// Every path passed to [delete].
  final List<String> deletedPaths = [];

  @override
  Future<http.Response> get(String path) async {
    if (path.startsWith('/events')) {
      return http.Response(jsonEncode(events), 200);
    }
    return http.Response('', 404);
  }

  @override
  Future<http.Response> delete(String path) async {
    deletedPaths.add(path);
    return http.Response('', 204);
  }

  // --- Storage stubs (not needed for these tests) ---
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
      throw UnimplementedError();
  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async =>
      throw UnimplementedError();
  @override
  Future<http.Response> patch(String path,
          [Map<String, dynamic>? body]) async =>
      throw UnimplementedError();
}

/// Fake [ApiService] that can simulate delete failures for testing error
/// handling (qa1 rework).
class _FailableApiService implements ApiService {
  @override
  Future<String?> createWidgetKey() async => null;
  _FailableApiService({this.events = const []});

  @override
  void Function()? onSessionExpired;

  List<Map<String, dynamic>> events;
  final List<String> deletedPaths = [];

  /// When true, [delete] returns 500 instead of 204.
  bool deleteWillFail = false;

  /// When true, [delete] throws an exception (simulates network loss).
  bool deleteWillThrow = false;

  @override
  Future<http.Response> get(String path) async {
    if (path.startsWith('/events')) {
      return http.Response(jsonEncode(events), 200);
    }
    return http.Response('', 404);
  }

  @override
  Future<http.Response> delete(String path) async {
    deletedPaths.add(path);
    if (deleteWillThrow) {
      throw Exception('Network error: connection refused');
    }
    if (deleteWillFail) {
      return http.Response('Internal Server Error', 500);
    }
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
      throw UnimplementedError();
  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async =>
      throw UnimplementedError();
  @override
  Future<http.Response> patch(String path,
          [Map<String, dynamic>? body]) async =>
      throw UnimplementedError();
}

/// Fake [ApiService] whose [delete] hangs until a [Completer] is completed,
/// allowing tests to observe the in-flight window (qa1 rework part b).
class _SlowDeleteApiService implements ApiService {
  @override
  Future<String?> createWidgetKey() async => null;
  _SlowDeleteApiService({this.events = const [], required this.deleteCompleter});

  @override
  void Function()? onSessionExpired;

  List<Map<String, dynamic>> events;
  final Completer<http.Response> deleteCompleter;
  final List<String> deletedPaths = [];

  @override
  Future<http.Response> get(String path) async {
    if (path.startsWith('/events')) {
      return http.Response(jsonEncode(events), 200);
    }
    return http.Response('', 404);
  }

  @override
  Future<http.Response> delete(String path) async {
    deletedPaths.add(path);
    return deleteCompleter.future;
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
      throw UnimplementedError();
  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async =>
      throw UnimplementedError();
  @override
  Future<http.Response> patch(String path,
          [Map<String, dynamic>? body]) async =>
      throw UnimplementedError();
}

/// Testable [CalendarProvider] that suppresses HomeWidget platform calls.
class _TestableCalendarProvider extends CalendarProvider {
  _TestableCalendarProvider({required ApiService api}) : super(api: api);

  @override
  void triggerWidgetUpdates() {
    // No-op: HomeWidget is not available in tests.
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

Map<String, dynamic> _makeEvent(String id, {String title = 'Test Event'}) => {
      'id': id,
      'title': title,
      'startTime': '2026-10-01T10:00:00.000Z',
      'endTime': '2026-10-01T11:00:00.000Z',
      'isAllDay': false,
      'category': 'PERSONAL',
      'calendarId': 'cal-1',
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Deferred delete (#114)', () {
    // dw1: deleteEventDeferred hides event immediately, API delete fires after
    // grace period.
    test('test_114_deferred_delete_hides_then_commits', () {
      fakeAsync((async) {
        final eventData = _makeEvent('evt-1');
        final fake = _FakeApiService(events: [eventData]);
        final provider = _TestableCalendarProvider(api: fake);

        // Load initial events
        provider.loadEvents();
        async.flushMicrotasks();
        expect(provider.events, hasLength(1),
            reason: 'precondition: one event loaded');

        // Call deferred delete
        provider.deleteEventDeferred('evt-1');
        async.flushMicrotasks();

        // Event must be gone from visible list immediately
        expect(provider.events.where((e) => e.id == 'evt-1'), isEmpty,
            reason: 'event must disappear from list immediately');

        // API delete must NOT have been called yet
        expect(fake.deletedPaths, isEmpty,
            reason: 'API delete must not fire before grace period');

        // Advance fake clock past the 5-second grace period
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // API delete must have been called exactly once
        expect(fake.deletedPaths, hasLength(1),
            reason: 'API delete must fire exactly once after grace period');
        expect(fake.deletedPaths.first, contains('evt-1'),
            reason: 'delete must target the correct event id');
      });
    });

    // dw2: undoDelete restores event and prevents API delete forever.
    test('test_114_undo_restores_and_never_deletes', () {
      fakeAsync((async) {
        final eventData = _makeEvent('evt-1');
        final fake = _FakeApiService(events: [eventData]);
        final provider = _TestableCalendarProvider(api: fake);

        // Load events
        provider.loadEvents();
        async.flushMicrotasks();
        expect(provider.events, hasLength(1));

        // Deferred delete
        provider.deleteEventDeferred('evt-1');
        async.flushMicrotasks();
        expect(provider.events.where((e) => e.id == 'evt-1'), isEmpty,
            reason: 'precondition: event removed after deferred delete');

        // Undo before timer fires
        provider.undoDelete('evt-1');
        async.flushMicrotasks();

        // Event must reappear
        expect(provider.events.where((e) => e.id == 'evt-1'), hasLength(1),
            reason: 'event must reappear after undo');

        // Advance well past grace period
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        // API delete must NEVER have been called
        expect(fake.deletedPaths, isEmpty,
            reason: 'API delete must never fire after undo, regardless of time');
      });
    });

    // dw3: loadEvents during grace period does not resurrect the event.
    test('test_114_reload_during_grace_keeps_it_hidden', () {
      fakeAsync((async) {
        final eventData = _makeEvent('evt-1');
        final fake = _FakeApiService(events: [eventData]);
        final provider = _TestableCalendarProvider(api: fake);

        // Load events
        provider.loadEvents();
        async.flushMicrotasks();
        expect(provider.events, hasLength(1));

        // Deferred delete
        provider.deleteEventDeferred('evt-1');
        async.flushMicrotasks();
        expect(provider.events.where((e) => e.id == 'evt-1'), isEmpty);

        // Reload events -- server still returns the event
        provider.loadEvents();
        async.flushMicrotasks();

        // Event must stay hidden despite server returning it
        expect(provider.events.where((e) => e.id == 'evt-1'), isEmpty,
            reason:
                'event must stay hidden when loadEvents returns it during grace period');
      });
    });

    // dw5: second deferred delete does not resurrect the first.
    test('test_114_second_delete_does_not_resurrect_first', () {
      fakeAsync((async) {
        final eventA = _makeEvent('evt-A', title: 'Event A');
        final eventB = _makeEvent('evt-B', title: 'Event B');
        final fake = _FakeApiService(events: [eventA, eventB]);
        final provider = _TestableCalendarProvider(api: fake);

        // Load events
        provider.loadEvents();
        async.flushMicrotasks();
        expect(provider.events, hasLength(2));

        // Deferred delete A
        provider.deleteEventDeferred('evt-A');
        async.flushMicrotasks();
        expect(provider.events.where((e) => e.id == 'evt-A'), isEmpty,
            reason: 'A must disappear');
        expect(provider.events.where((e) => e.id == 'evt-B'), hasLength(1),
            reason: 'B must still be visible');

        // Deferred delete B before A's timer fires
        provider.deleteEventDeferred('evt-B');
        async.flushMicrotasks();
        expect(provider.events.where((e) => e.id == 'evt-B'), isEmpty,
            reason: 'B must disappear');

        // A must NOT have reappeared
        expect(provider.events.where((e) => e.id == 'evt-A'), isEmpty,
            reason: 'A must NOT reappear when B is deferred-deleted');

        // Advance past both grace periods
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        // Both API deletes must have fired
        final deletedEvtA =
            fake.deletedPaths.where((p) => p.contains('evt-A'));
        final deletedEvtB =
            fake.deletedPaths.where((p) => p.contains('evt-B'));
        expect(deletedEvtA, hasLength(1),
            reason: 'API delete for A must fire exactly once');
        expect(deletedEvtB, hasLength(1),
            reason: 'API delete for B must fire exactly once');
      });
    });

    // spec1 rework: undoDelete restores event at its original position, not
    // appended at the end.
    test('test_114_undo_restores_at_original_position', () {
      fakeAsync((async) {
        final eventA = _makeEvent('evt-A', title: 'Event A');
        final eventB = _makeEvent('evt-B', title: 'Event B');
        final eventC = _makeEvent('evt-C', title: 'Event C');
        final fake = _FakeApiService(events: [eventA, eventB, eventC]);
        final provider = _TestableCalendarProvider(api: fake);

        provider.loadEvents();
        async.flushMicrotasks();
        expect(provider.events.map((e) => e.id).toList(),
            ['evt-A', 'evt-B', 'evt-C'],
            reason: 'precondition: three events loaded in order');

        // Delete the middle event (index 1)
        provider.deleteEventDeferred('evt-B');
        async.flushMicrotasks();
        expect(provider.events.map((e) => e.id).toList(), ['evt-A', 'evt-C'],
            reason: 'middle event removed');

        // Undo
        provider.undoDelete('evt-B');
        async.flushMicrotasks();

        // Event B must be back at its original position (index 1), not
        // appended at the end.
        expect(provider.events.map((e) => e.id).toList(),
            ['evt-A', 'evt-B', 'evt-C'],
            reason:
                'undoDelete must restore event at its original position (issue #114: 같은 자리로)');

        provider.dispose();
      });
    });

    // qa1 rework: API delete failure (non-204) restores the event.
    test('test_114_deferred_delete_failure_restores_event', () {
      fakeAsync((async) {
        final eventData = _makeEvent('evt-1');
        final fake = _FailableApiService(events: [eventData]);
        fake.deleteWillFail = true;
        final provider = _TestableCalendarProvider(api: fake);

        provider.loadEvents();
        async.flushMicrotasks();
        expect(provider.events, hasLength(1),
            reason: 'precondition: one event loaded');

        // Deferred delete
        provider.deleteEventDeferred('evt-1');
        async.flushMicrotasks();
        expect(provider.events.where((e) => e.id == 'evt-1'), isEmpty,
            reason: 'event must disappear immediately');

        // Advance past grace period -- API delete fires but returns 500
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Event must be restored because the API delete returned non-204
        expect(provider.events.where((e) => e.id == 'evt-1'), hasLength(1),
            reason:
                'event must be restored when API delete fails (non-204 response)');

        provider.dispose();
      });
    });

    // qa1 rework: API delete exception (network error) restores the event.
    test('test_114_deferred_delete_exception_restores_event', () {
      fakeAsync((async) {
        final eventData = _makeEvent('evt-1');
        final fake = _FailableApiService(events: [eventData]);
        fake.deleteWillThrow = true;
        final provider = _TestableCalendarProvider(api: fake);

        provider.loadEvents();
        async.flushMicrotasks();
        expect(provider.events, hasLength(1),
            reason: 'precondition: one event loaded');

        // Deferred delete
        provider.deleteEventDeferred('evt-1');
        async.flushMicrotasks();
        expect(provider.events.where((e) => e.id == 'evt-1'), isEmpty,
            reason: 'event must disappear immediately');

        // Advance past grace period -- API delete throws
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Event must be restored because the API delete threw
        expect(provider.events.where((e) => e.id == 'evt-1'), hasLength(1),
            reason:
                'event must be restored when API delete throws (network error)');

        provider.dispose();
      });
    });

    // qa1 rework: during in-flight API delete, loadEvents still filters the
    // pending-delete event (the id must remain in the filter set until the
    // API call completes). Uses a Completer-based fake to hold the delete
    // in-flight so we can observe the window.
    test('test_114_inflight_delete_keeps_event_filtered', () {
      fakeAsync((async) {
        final eventData = _makeEvent('evt-1');
        final deleteCompleter = Completer<http.Response>();
        final fake = _SlowDeleteApiService(
          events: [eventData],
          deleteCompleter: deleteCompleter,
        );
        final provider = _TestableCalendarProvider(api: fake);

        provider.loadEvents();
        async.flushMicrotasks();
        expect(provider.events, hasLength(1));

        provider.deleteEventDeferred('evt-1');
        async.flushMicrotasks();

        // Fire the timer -- the async callback starts but awaits the
        // Completer-controlled _api.delete, so the delete is in-flight.
        async.elapse(const Duration(seconds: 5));

        // Trigger a concurrent loadEvents while the delete is in-flight.
        // The server still returns the event, but it must stay filtered
        // because the id is still in _pendingDeleteEvents.
        provider.loadEvents();
        async.flushMicrotasks();

        // The event must NOT have reappeared from the server response
        // during the in-flight delete window.
        expect(provider.events.where((e) => e.id == 'evt-1'), isEmpty,
            reason:
                'event must stay filtered during in-flight API delete');

        // Complete the delete so the test can clean up without pending futures.
        deleteCompleter.complete(http.Response('', 204));
        async.flushMicrotasks();

        provider.dispose();
      });
    });
  });
}
