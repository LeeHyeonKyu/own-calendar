import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:own_calendar/providers/calendar_provider.dart';
import 'package:own_calendar/services/api_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory fake [ApiService] for CalendarProvider tests.
///
/// Supports configurable responses per path and exception throwing.
class _FakeApiService implements ApiService {
  _FakeApiService({this.onGet});

  @override
  void Function()? onSessionExpired;

  /// Callback that determines the response for a GET request.
  /// If null or throws, the test controls the failure path.
  http.Response Function(String path)? onGet;
  bool throwOnGet = false;
  String throwMessage = 'Network unreachable';

  @override
  Future<http.Response> get(String path) async {
    if (throwOnGet) throw Exception(throwMessage);
    return onGet?.call(path) ?? http.Response('', 500);
  }

  // Storage — not needed for CalendarProvider tests but required by interface
  @override
  Future<String?> get accessToken async => 'fake-token';
  @override
  Future<String?> get refreshToken async => 'fake-refresh';
  @override
  Future<String?> get cachedUserJson async => null;
  @override
  Future<void> saveTokens(String access, String refresh) async {}
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
  Future<http.Response> delete(String path) async =>
      throw UnimplementedError();
  @override
  Future<http.Response> patch(String path,
          [Map<String, dynamic>? body]) async =>
      throw UnimplementedError();
}

/// Subclass of [CalendarProvider] that tracks widget update calls.
///
/// Overrides [triggerWidgetUpdates] to count invocations without calling
/// the real HomeWidget platform APIs (which are unavailable in tests).
class _TrackableCalendarProvider extends CalendarProvider {
  _TrackableCalendarProvider({
    required ApiService api,
  }) : super(api: api);

  int widgetUpdateCallCount = 0;

  @override
  void triggerWidgetUpdates() {
    widgetUpdateCallCount++;
    // Do not call super — HomeWidget platform calls are not available in tests
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _sampleEvent = {
  'id': 'evt-1',
  'title': 'Team Meeting',
  'startTime': '2026-09-30T10:00:00.000Z',
  'endTime': '2026-09-30T11:00:00.000Z',
  'isAllDay': false,
  'category': 'WORK',
  'calendarId': 'cal-1',
};

final _sampleEvent2 = {
  'id': 'evt-2',
  'title': 'Lunch',
  'startTime': '2026-09-30T12:00:00.000Z',
  'endTime': '2026-09-30T13:00:00.000Z',
  'isAllDay': false,
  'category': 'PERSONAL',
  'calendarId': 'cal-1',
};

String _eventsJson(List<Map<String, dynamic>> events) => jsonEncode(events);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CalendarProvider error handling (#108)', () {
    // -----------------------------------------------------------------------
    // dw3: Failed fetch sets error state and preserves existing events
    // -----------------------------------------------------------------------
    group('test_108_failed_fetch_error_and_preserves_data', () {
      test('non-200 response sets error and preserves existing events',
          () async {
        final fake = _FakeApiService(
          onGet: (_) => http.Response(_eventsJson([_sampleEvent]), 200),
        );
        final provider = CalendarProvider(api: fake);

        // First load succeeds — establishes baseline data
        await provider.loadEvents();
        expect(provider.events, hasLength(1));
        expect(provider.error, isNull);
        final eventsBefore = List.of(provider.events);

        // Now make the API return 500
        fake.onGet = (_) => http.Response('Server Error', 500);

        await provider.loadEvents();

        // Assert: error is set, events are preserved, isLoading is false
        expect(provider.error, isNotNull,
            reason: 'error getter must be non-null after non-200 response');
        expect(provider.isLoading, isFalse,
            reason: 'isLoading must be false after failure');
        expect(provider.events, hasLength(eventsBefore.length),
            reason: 'Existing events must be preserved on failure');
        expect(provider.events.first.id, eventsBefore.first.id,
            reason: 'Event identity must be preserved');
      });

      test('thrown exception sets error and preserves existing events',
          () async {
        final fake = _FakeApiService(
          onGet: (_) =>
              http.Response(_eventsJson([_sampleEvent, _sampleEvent2]), 200),
        );
        final provider = CalendarProvider(api: fake);

        // First load succeeds
        await provider.loadEvents();
        expect(provider.events, hasLength(2));
        final eventsBefore = List.of(provider.events);

        // Now make the API throw
        fake.throwOnGet = true;

        await provider.loadEvents();

        expect(provider.error, isNotNull,
            reason: 'error getter must be non-null after thrown exception');
        expect(provider.isLoading, isFalse,
            reason: 'isLoading must be false after exception');
        expect(provider.events, hasLength(eventsBefore.length),
            reason: 'Existing events must be preserved on exception');
        // Verify event identity is preserved, not just list length (dw3 rubric:
        // "events list is identical to pre-call state" for both paths)
        expect(provider.events.first.id, eventsBefore.first.id,
            reason: 'First event identity must be preserved on exception');
        expect(provider.events.last.id, eventsBefore.last.id,
            reason: 'Last event identity must be preserved on exception');
      });

      test('non-200 without prior data keeps empty list and sets error',
          () async {
        // No prior successful load — events list starts empty
        final fake = _FakeApiService(
          onGet: (_) => http.Response('Bad Gateway', 502),
        );
        final provider = CalendarProvider(api: fake);

        await provider.loadEvents();

        expect(provider.error, isNotNull);
        expect(provider.events, isEmpty,
            reason: 'Empty initial list is preserved (not replaced)');
        expect(provider.isLoading, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // dw4: Error cleared on success
    // -----------------------------------------------------------------------
    test('test_108_error_cleared_on_success', () async {
      final fake = _FakeApiService(
        onGet: (_) => http.Response('Server Error', 500),
      );
      final provider = CalendarProvider(api: fake);

      // First load fails — error is set
      await provider.loadEvents();
      expect(provider.error, isNotNull, reason: 'precondition: error must be set');

      // Now make the API return 200
      fake.onGet = (_) => http.Response(_eventsJson([_sampleEvent]), 200);

      await provider.loadEvents();

      expect(provider.error, isNull,
          reason: 'Error must be cleared to null after a successful 200 load');
      expect(provider.events, hasLength(1));
    });

    // -----------------------------------------------------------------------
    // dw5: Widget updates skipped on failure, executed on success
    // -----------------------------------------------------------------------
    group('test_108_no_widget_update_on_failure', () {
      test('success triggers widget update', () async {
        final fake = _FakeApiService(
          onGet: (_) => http.Response(_eventsJson([_sampleEvent]), 200),
        );
        final provider = _TrackableCalendarProvider(api: fake);

        await provider.loadEvents();

        expect(provider.widgetUpdateCallCount, 1,
            reason: 'Widget updates must be triggered on success');
      });

      test('non-200 response does not trigger widget update', () async {
        final fake = _FakeApiService(
          onGet: (_) => http.Response('Internal Server Error', 500),
        );
        final provider = _TrackableCalendarProvider(api: fake);

        await provider.loadEvents();

        expect(provider.widgetUpdateCallCount, 0,
            reason:
                'Widget updates must NOT be triggered on non-200 response');
      });

      test('thrown exception does not trigger widget update', () async {
        final fake = _FakeApiService();
        fake.throwOnGet = true;
        final provider = _TrackableCalendarProvider(api: fake);

        await provider.loadEvents();

        expect(provider.widgetUpdateCallCount, 0,
            reason:
                'Widget updates must NOT be triggered on thrown exception');
      });
    });

  });
}
