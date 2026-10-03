import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:own_calendar/models/category.dart';
import 'package:own_calendar/models/event.dart';
import 'package:own_calendar/providers/calendar_provider.dart';
import 'package:own_calendar/providers/category_provider.dart';
import 'package:own_calendar/screens/event_form_screen.dart';
import 'package:own_calendar/services/api_service.dart';
import 'package:own_calendar/widgets/event_card.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory fake [ApiService] for EventFormScreen tests.
///
/// Returns controllable responses per path prefix and captures POST/PUT
/// payloads so tests can inspect the save data.
class _FakeApiService implements ApiService {
  final Map<String, http.Response Function(String)> _getHandlers = {};
  final List<Map<String, dynamic>> capturedPosts = [];
  final List<Map<String, dynamic>> capturedPuts = [];

  void onGet(String pathPrefix, http.Response Function(String) handler) {
    _getHandlers[pathPrefix] = handler;
  }

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
  Future<http.Response> get(String path) async {
    for (final entry in _getHandlers.entries) {
      if (path.startsWith(entry.key)) {
        return entry.value(path);
      }
    }
    return http.Response('[]', 200);
  }

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    capturedPosts.add(Map.from(body));
    // Return 201 so createEvent considers it success, then loadEvents follows
    return http.Response('{"id":"new-evt-1"}', 201);
  }

  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    capturedPuts.add(Map.from(body));
    return http.Response('{"id":"evt-1"}', 200);
  }

  @override
  Future<http.Response> delete(String path) async =>
      http.Response('', 204);

  @override
  Future<http.Response> patch(String path,
      [Map<String, dynamic>? body]) async =>
      http.Response('', 200);
}

/// Test subclass of [CategoryProvider] that exposes categories directly
/// without requiring a real API call.
///
/// The real CategoryProvider creates a private ApiService internally;
/// this subclass bypasses it entirely by overriding all public accessors.
class _TestCategoryProvider extends CategoryProvider {
  final List<CategoryModel> _testCategories;

  _TestCategoryProvider(this._testCategories);

  @override
  List<CategoryModel> get categories => _testCategories;

  @override
  bool get isLoading => false;

  @override
  CategoryModel? get defaultCategory {
    try {
      return _testCategories.firstWhere((c) => c.isDefault);
    } catch (_) {
      return _testCategories.isNotEmpty ? _testCategories.first : null;
    }
  }

  @override
  CategoryModel? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _testCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> loadCategories() async {
    // No-op: categories are controlled via constructor
  }
}

/// Test subclass of [CalendarProvider] that suppresses HomeWidget platform
/// calls which are unavailable in the test environment.
class _TestCalendarProvider extends CalendarProvider {
  _TestCalendarProvider({required super.api});

  @override
  void triggerWidgetUpdates() {
    // Suppress — HomeWidget platform APIs are not available in tests
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _calendarJson = {
  'id': 'cal-test-1',
  'name': 'Test Calendar',
  'color': '#4A90D9',
  'isDefault': true,
  'visibility': 'PUBLIC',
  'type': 'PERSONAL',
};

CategoryModel _cat({
  required String id,
  required String name,
  required String color,
  String? emoji,
  bool isDefault = false,
}) =>
    CategoryModel(
      id: id,
      name: name,
      color: color,
      emoji: emoji,
      isDefault: isDefault,
    );

/// Three categories: Work (no default), Personal (default), Health (has emoji).
List<CategoryModel> _threeCats() => [
      _cat(id: 'cat-1', name: 'Work', color: '#4A90D9'),
      _cat(id: 'cat-2', name: 'Personal', color: '#50C878', isDefault: true),
      _cat(
          id: 'cat-3',
          name: 'Health',
          color: '#FF9800',
          emoji: '\u{1F3C3}'),
    ];

/// Wraps [EventFormScreen] in a GoRouter + MultiProvider test harness.
///
/// Provides CalendarProvider and CategoryProvider to the widget tree and
/// sets up GoRouter so context.pop() works.
Widget _buildFormHarness({
  required CalendarProvider calendarProvider,
  required CategoryProvider categoryProvider,
  String? eventId,
  DateTime? initialDate,
}) {
  // Nest event routes under '/' so context.pop() has somewhere to go.
  final router = GoRouter(
    initialLocation: eventId != null ? '/event/$eventId/edit' : '/event/new',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('Home')),
        routes: [
          GoRoute(
            path: 'event/new',
            builder: (context, state) =>
                EventFormScreen(initialDate: initialDate),
          ),
          GoRoute(
            path: 'event/:id/edit',
            builder: (context, state) =>
                EventFormScreen(eventId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CalendarProvider>.value(value: calendarProvider),
      ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Builds a _FakeApiService pre-configured to return one calendar and an
/// empty event list on GET, and captures POST/PUT payloads.
_FakeApiService _defaultFakeApi({List<Map<String, dynamic>>? events}) {
  final api = _FakeApiService();
  api.onGet('/calendars',
      (_) => http.Response(jsonEncode([_calendarJson]), 200));
  api.onGet('/events',
      (_) => http.Response(jsonEncode(events ?? []), 200));
  return api;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── dw1: Event form shows custom category chips ──────────────────────────
  group('test_111_event_form_shows_custom_category_chips', () {
    testWidgets(
        'renders 3 category chips with correct names and no legacy dropdown',
        (tester) async {
      final api = _defaultFakeApi();
      final calProvider = _TestCalendarProvider(api: api);
      await calProvider.loadCalendars();

      final catProvider = _TestCategoryProvider(_threeCats());

      await tester.pumpWidget(
          _buildFormHarness(
              calendarProvider: calProvider,
              categoryProvider: catProvider));
      await tester.pumpAndSettle();

      // Verify 3 chips are rendered with the expected category names.
      // Health has emoji prefix in its label: '🏃 Health'.
      expect(find.widgetWithText(ChoiceChip, 'Work'), findsOneWidget,
          reason: 'Work category chip must be rendered');
      expect(find.widgetWithText(ChoiceChip, 'Personal'), findsOneWidget,
          reason: 'Personal category chip must be rendered');
      expect(find.widgetWithText(ChoiceChip, '\u{1F3C3} Health'),
          findsOneWidget,
          reason: 'Health category chip must be rendered with emoji');

      // Legacy category dropdown must be absent.
      // The old dropdown had items from EventModel.categoryLabels which include
      // Korean labels like '업무', '개인', etc. Check that those legacy labels
      // do NOT appear (they would only come from the old dropdown).
      expect(find.text('업무'), findsNothing,
          reason:
              'Legacy dropdown label "업무" (Work) must be absent '
              'now that the dropdown is replaced by chips');
      expect(find.text('개인'), findsNothing,
          reason:
              'Legacy dropdown label "개인" (Personal) must be absent');
    });
  });

  // ── dw2: Default and edit preselect ──────────────────────────────────────
  group('test_111_default_and_edit_preselect', () {
    testWidgets('new-event form preselects the isDefault category chip',
        (tester) async {
      final api = _defaultFakeApi();
      final calProvider = _TestCalendarProvider(api: api);
      await calProvider.loadCalendars();
      final catProvider = _TestCategoryProvider(_threeCats());

      await tester.pumpWidget(
          _buildFormHarness(
              calendarProvider: calProvider,
              categoryProvider: catProvider));
      await tester.pumpAndSettle();

      // The default category is cat-2 (Personal). Its chip must be selected.
      final personalChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Personal'));
      expect(personalChip.selected, isTrue,
          reason:
              'The isDefault category (Personal) must be pre-selected '
              'in a new-event form');

      // Non-default chips must NOT be selected
      final workChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Work'));
      expect(workChip.selected, isFalse,
          reason: 'Non-default category Work must not be selected');

      // Save and verify categoryId in payload
      await tester.enterText(
          find.widgetWithText(TextFormField, '제목'), 'Test Event');
      await tester.pumpAndSettle();
      // ListView lazily renders — scroll until the save button is built
      await tester.scrollUntilVisible(
          find.text('저장'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(api.capturedPosts, isNotEmpty,
          reason: 'createEvent must have been called');
      expect(api.capturedPosts.last['categoryId'], equals('cat-2'),
          reason:
              'New event payload categoryId must equal the default '
              'category id (cat-2)');
    });

    testWidgets('tapping a different chip changes the saved categoryId',
        (tester) async {
      final api = _defaultFakeApi();
      final calProvider = _TestCalendarProvider(api: api);
      await calProvider.loadCalendars();
      final catProvider = _TestCategoryProvider(_threeCats());

      await tester.pumpWidget(
          _buildFormHarness(
              calendarProvider: calProvider,
              categoryProvider: catProvider));
      await tester.pumpAndSettle();

      // Tap the Work chip (cat-1) to change selection
      await tester.tap(find.widgetWithText(ChoiceChip, 'Work'));
      await tester.pumpAndSettle();

      // Work chip is now selected, Personal is not
      final workChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Work'));
      expect(workChip.selected, isTrue,
          reason: 'Work chip must be selected after tapping');

      final personalChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Personal'));
      expect(personalChip.selected, isFalse,
          reason: 'Personal chip must be deselected after selecting Work');

      // Save and check payload
      await tester.enterText(
          find.widgetWithText(TextFormField, '제목'), 'Work Event');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('저장'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(api.capturedPosts, isNotEmpty);
      expect(api.capturedPosts.last['categoryId'], equals('cat-1'),
          reason: 'After tapping Work chip, categoryId must be cat-1');
    });

    testWidgets('edit form preselects the event existing categoryId chip',
        (tester) async {
      final eventJson = {
        'id': 'evt-edit-1',
        'title': 'Morning Run',
        'startTime': '2026-10-01T07:00:00.000Z',
        'endTime': '2026-10-01T08:00:00.000Z',
        'isAllDay': false,
        'category': 'PERSONAL',
        'calendarId': 'cal-test-1',
        'categoryId': 'cat-3',
      };
      final api = _defaultFakeApi(events: [eventJson]);
      final calProvider = _TestCalendarProvider(api: api);
      await calProvider.loadCalendars();
      await calProvider.loadEvents();
      final catProvider = _TestCategoryProvider(_threeCats());

      await tester.pumpWidget(
          _buildFormHarness(
              calendarProvider: calProvider,
              categoryProvider: catProvider,
              eventId: 'evt-edit-1'));
      await tester.pumpAndSettle();

      // The event has categoryId = cat-3 (Health). That chip must be selected.
      // Health has emoji prefix in its label: '🏃 Health'.
      final healthChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, '\u{1F3C3} Health'));
      expect(healthChip.selected, isTrue,
          reason:
              'Edit form must preselect the chip matching the event '
              'categoryId (cat-3 Health)');

      // Other chips must not be selected
      final personalChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Personal'));
      expect(personalChip.selected, isFalse,
          reason: 'Personal chip must not be selected in edit mode');
    });
  });

  // ── dw3: EventCard prefers categoryColor ────────────────────────────────
  group('test_111_event_card_prefers_category_color', () {
    testWidgets('uses categoryColor for border when present', (tester) async {
      final event = EventModel(
        id: 'evt-cc-1',
        title: 'Category Color Event',
        startTime: DateTime(2026, 10, 1, 10, 0),
        endTime: DateTime(2026, 10, 1, 11, 0),
        calendarId: 'cal-1',
        calendarColor: '#0000FF', // blue
        categoryColor: '#FF0000', // red — should take priority
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EventCard(event: event)),
      ));

      // Find the Container whose BoxDecoration has a left Border with width 3
      final decorated = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final dec = w.decoration;
        if (dec is! BoxDecoration) return false;
        final border = dec.border;
        if (border is! Border) return false;
        return border.left.width == 3;
      });
      expect(decorated, findsOneWidget);

      final box =
          (tester.widget<Container>(decorated).decoration as BoxDecoration)
              .border as Border;
      // categoryColor #FF0000 -> Color(0xFFFF0000)
      expect(box.left.color, equals(const Color(0xFFFF0000)),
          reason:
              'Border color must be categoryColor (red) not calendarColor (blue)');
    });

    testWidgets('falls back to calendarColor when categoryColor is null',
        (tester) async {
      final event = EventModel(
        id: 'evt-cc-2',
        title: 'No Category Color',
        startTime: DateTime(2026, 10, 1, 10, 0),
        endTime: DateTime(2026, 10, 1, 11, 0),
        calendarId: 'cal-1',
        calendarColor: '#00FF00', // green
        categoryColor: null, // not set
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EventCard(event: event)),
      ));

      final decorated = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final dec = w.decoration;
        if (dec is! BoxDecoration) return false;
        final border = dec.border;
        if (border is! Border) return false;
        return border.left.width == 3;
      });
      expect(decorated, findsOneWidget);

      final box =
          (tester.widget<Container>(decorated).decoration as BoxDecoration)
              .border as Border;
      // calendarColor #00FF00 -> Color(0xFF00FF00)
      expect(box.left.color, equals(const Color(0xFF00FF00)),
          reason:
              'Border color must fall back to calendarColor (green) '
              'when categoryColor is null');
    });
  });

  // ── dw4: Legacy category field still sent ───────────────────────────────
  group('test_111_legacy_category_field_still_sent', () {
    testWidgets(
        'save payload includes legacy category enum string after chip selection',
        (tester) async {
      final api = _defaultFakeApi();
      final calProvider = _TestCalendarProvider(api: api);
      await calProvider.loadCalendars();
      final catProvider = _TestCategoryProvider(_threeCats());

      await tester.pumpWidget(
          _buildFormHarness(
              calendarProvider: calProvider,
              categoryProvider: catProvider));
      await tester.pumpAndSettle();

      // Select a custom chip (Work)
      await tester.tap(find.widgetWithText(ChoiceChip, 'Work'));
      await tester.pumpAndSettle();

      // Enter title and save
      await tester.enterText(
          find.widgetWithText(TextFormField, '제목'), 'Legacy Test');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('저장'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(api.capturedPosts, isNotEmpty,
          reason: 'createEvent must have been called');
      final payload = api.capturedPosts.last;
      expect(payload.containsKey('category'), isTrue,
          reason:
              'Payload must still contain the legacy "category" key');
      expect(payload['category'], isA<String>(),
          reason: 'Legacy category value must be a non-null string');
      expect((payload['category'] as String).isNotEmpty, isTrue,
          reason: 'Legacy category must not be empty');
    });
  });

  // ── dw5: Empty categories hides chips ───────────────────────────────────
  group('test_111_empty_categories_hides_chips', () {
    testWidgets(
        'no chips rendered and categoryId absent when categories list is empty',
        (tester) async {
      final api = _defaultFakeApi();
      final calProvider = _TestCalendarProvider(api: api);
      await calProvider.loadCalendars();
      final catProvider = _TestCategoryProvider([]); // empty

      await tester.pumpWidget(
          _buildFormHarness(
              calendarProvider: calProvider,
              categoryProvider: catProvider));
      await tester.pumpAndSettle();

      // No ChoiceChip widgets should exist
      expect(find.byType(ChoiceChip), findsNothing,
          reason:
              'No category chips must render when categories list is empty');

      // Enter title and save
      await tester.enterText(
          find.widgetWithText(TextFormField, '제목'),
          'No Category Event');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('저장'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(api.capturedPosts, isNotEmpty,
          reason: 'createEvent must have been called');
      final categoryId = api.capturedPosts.last['categoryId'];
      expect(categoryId, isNull,
          reason:
              'categoryId must be null when no categories are available');
    });
  });
}
