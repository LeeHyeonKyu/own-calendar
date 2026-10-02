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
  _FakeApiService({this.events = const []});

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
  });
}
