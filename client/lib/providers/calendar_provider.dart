import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar.dart';
import '../models/category.dart';
import '../models/event.dart';
import '../models/holiday.dart';
import '../models/task.dart';
import '../services/api_service.dart';

class CalendarProvider extends ChangeNotifier {
  CalendarProvider({ApiService? api})
      : _api = api ?? ApiService();

  static const _kHiddenCategoryIds = 'hidden_category_ids';
  static const _kHideUncategorized = 'hide_uncategorized';

  final ApiService _api;
  List<CalendarModel> _calendars = [];
  List<EventModel> _events = [];
  List<EventModel> _groupEvents = [];
  List<CategoryModel> _categories = [];
  List<TaskModel> _tasks = [];
  final List<HolidayModel> _holidays = [];
  bool _isLoading = false;
  String? _error;
  bool _showGroupEvents = true;
  Set<String> _hiddenCategoryIds = {};
  bool _hideUncategorized = false;

  /// Pending deferred deletes: event id -> timer.
  final Map<String, Timer> _pendingDeleteTimers = {};

  /// Stashed events awaiting deferred delete (for undo restoration).
  /// Stores the event and its original index in [_events] for
  /// position-preserving undo (spec1 rework: issue #114 같은 자리로).
  final Map<String, ({EventModel event, int index})> _pendingDeleteEvents = {};

  /// IDs of events whose deferred delete is pending -- used to filter them
  /// out of [_events] when [loadEvents] refreshes from the server.
  /// Derived from [_pendingDeleteEvents] (not [_pendingDeleteTimers]) so that
  /// events remain filtered during the in-flight API delete window after the
  /// timer fires but before the API call completes (qa1 rework).
  Set<String> get _pendingDeleteIds => _pendingDeleteEvents.keys.toSet();

  List<CalendarModel> get calendars => _calendars;
  List<EventModel> get events => _events;
  List<EventModel> get groupEvents => _groupEvents;
  List<CategoryModel> get categories => _categories;
  List<TaskModel> get tasks => _tasks;
  List<HolidayModel> get holidays => _holidays;
  List<EventModel> get allVisibleEvents {
    final merged = _showGroupEvents ? [..._events, ..._groupEvents] : _events;
    if (_hiddenCategoryIds.isEmpty && !_hideUncategorized) {
      return merged;
    }
    return merged.where((e) {
      if (e.categoryId == null) return !_hideUncategorized;
      return !_hiddenCategoryIds.contains(e.categoryId);
    }).toList();
  }
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showGroupEvents => _showGroupEvents;
  Set<String> get hiddenCategoryIds => _hiddenCategoryIds;
  bool get hideUncategorized => _hideUncategorized;
  bool get isAllCategoriesVisible =>
      _hiddenCategoryIds.isEmpty && !_hideUncategorized;

  void toggleGroupEvents() {
    _showGroupEvents = !_showGroupEvents;
    notifyListeners();
  }

  void toggleCategoryVisibility(String categoryId) {
    if (_hiddenCategoryIds.contains(categoryId)) {
      _hiddenCategoryIds.remove(categoryId);
    } else {
      _hiddenCategoryIds.add(categoryId);
    }
    _persistFilterState();
    notifyListeners();
  }

  void toggleUncategorized() {
    _hideUncategorized = !_hideUncategorized;
    _persistFilterState();
    notifyListeners();
  }

  void showAllCategories() {
    _hiddenCategoryIds.clear();
    _hideUncategorized = false;
    _persistFilterState();
    notifyListeners();
  }

  Future<void> _persistFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kHiddenCategoryIds, _hiddenCategoryIds.toList());
    await prefs.setBool(_kHideUncategorized, _hideUncategorized);
  }

  Future<void> _restoreFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(_kHiddenCategoryIds);
    if (hidden != null) {
      _hiddenCategoryIds = hidden.toSet();
    }
    _hideUncategorized = prefs.getBool(_kHideUncategorized) ?? false;
  }

  Future<void> loadCategories() async {
    final res = await _api.get('/categories');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      _categories = list.map((j) => CategoryModel.fromJson(j)).toList();
      await _restoreFilterState();
      // Remove hidden IDs that no longer exist in the DB
      final validIds = _categories.map((c) => c.id).toSet();
      final removed = _hiddenCategoryIds.difference(validIds);
      if (removed.isNotEmpty) {
        _hiddenCategoryIds.removeAll(removed);
        _persistFilterState();
      }
      notifyListeners();
    }
  }

  Future<void> _updateMonthlyWidget() async {
    try {
      final now = DateTime.now();
      // Build events map: day number -> list of event data
      final Map<String, List<Map<String, dynamic>>> eventsMap = {};

      final allEvents = [..._events, ..._groupEvents];
      for (final event in allEvents) {
        // Include events that fall within the current display month
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        if (event.endTime.isBefore(monthStart) ||
            event.startTime.isAfter(monthEnd)) {
          continue;
        }

        // Determine which days this event appears on
        final eventStart =
            event.startTime.isBefore(monthStart) ? monthStart : event.startTime;
        final eventEnd =
            event.endTime.isAfter(monthEnd) ? monthEnd : event.endTime;

        for (var d = DateTime(eventStart.year, eventStart.month, eventStart.day);
            !d.isAfter(eventEnd);
            d = d.add(const Duration(days: 1))) {
          if (d.month != now.month) continue;
          final dayKey = d.day.toString();
          eventsMap.putIfAbsent(dayKey, () => []);
          // Avoid duplicates (multi-day events)
          if (eventsMap[dayKey]!.any((e) => e['id'] == event.id)) continue;
          eventsMap[dayKey]!.add({
            'id': event.id,
            'title': event.title,
            'time': event.isAllDay
                ? '종일'
                : '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}',
            'endTime': event.isAllDay
                ? null
                : '${event.endTime.hour.toString().padLeft(2, '0')}:${event.endTime.minute.toString().padLeft(2, '0')}',
            'category': event.category,
            'isGroup': _groupEvents.contains(event),
          });
        }
      }

      // Build task days: which days have tasks
      final Map<String, bool> taskDaysMap = {};
      for (final task in _tasks) {
        final date = task.scheduledDate ?? task.dueDate;
        if (date == null) continue;
        if (date.month != now.month || date.year != now.year) continue;
        taskDaysMap[date.day.toString()] = true;
      }

      final monthlyData = {
        'year': now.year,
        'month': now.month,
        'events': eventsMap,
        'taskDays': taskDaysMap,
      };

      await HomeWidget.saveWidgetData('monthlyData', jsonEncode(monthlyData));
      await HomeWidget.updateWidget(
        iOSName: 'OwnCalendarMonthlyWidget',
        androidName: 'OwnCalendarMonthlyWidgetProvider',
      );
    } catch (_) {}
  }

  Future<void> _updateHomeWidget() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final todayEvents = allVisibleEvents
          .where((e) =>
              e.startTime.isBefore(todayEnd) && e.endTime.isAfter(todayStart))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      final widgetData = todayEvents
          .take(8)
          .map((e) => {
                'title': e.title,
                'time': e.isAllDay
                    ? '종일'
                    : '${e.startTime.hour.toString().padLeft(2, '0')}:${e.startTime.minute.toString().padLeft(2, '0')}',
                'category': e.category,
              })
          .toList();

      // Task data for widget
      final todayTasks = _tasks.where((t) {
        final date = t.scheduledDate ?? t.dueDate;
        if (date == null) return t.isTodo; // include unscheduled TODOs
        return date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
               date.isBefore(todayEnd);
      }).toList()
        ..sort((a, b) {
          // Overdue first, then by time
          if (a.isOverdue && !b.isOverdue) return -1;
          if (!a.isOverdue && b.isOverdue) return 1;
          final aTime = a.scheduledDate ?? a.dueDate;
          final bTime = b.scheduledDate ?? b.dueDate;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });

      final taskWidgetData = todayTasks.take(8).map((t) => {
        'title': t.title,
        'status': t.status,
        'priority': t.priority,
        'time': t.scheduledTime ?? '',
        'dueDate': t.dueDate?.toIso8601String() ?? '',
        'eventTitle': t.eventTitle ?? '',
        'isOverdue': t.isOverdue,
      }).toList();

      final doneCount = todayTasks.where((t) => t.isDone).length;
      final totalCount = todayTasks.length;

      await HomeWidget.saveWidgetData('todayEvents', jsonEncode(widgetData));
      await HomeWidget.saveWidgetData('todayTasks', jsonEncode(taskWidgetData));
      await HomeWidget.saveWidgetData('taskDone', doneCount);
      await HomeWidget.saveWidgetData('taskTotal', totalCount);
      await HomeWidget.saveWidgetData(
          'lastUpdated', DateTime.now().toIso8601String());
      await HomeWidget.saveWidgetData<bool>('isLoggedIn', true);
      await HomeWidget.updateWidget(
        iOSName: 'OwnCalendarWidget',
        androidName: 'OwnCalendarWidgetProvider',
      );
    } catch (_) {}
  }

  Future<void> loadCalendars() async {
    final res = await _api.get('/calendars');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      _calendars = list.map((j) => CalendarModel.fromJson(j)).toList();
      notifyListeners();
    }
  }

  Future<void> loadHolidays(int year, {int? month}) async {
    String query = 'year=$year';
    if (month != null) query += '&month=$month';
    final res = await _api.get('/holidays/holidays?$query');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      final newHolidays = list.map((j) => HolidayModel.fromJson(j)).toList();
      // Merge: remove holidays for this year+month range, then add new ones
      if (month != null) {
        _holidays.removeWhere((h) => h.date.year == year && h.date.month == month);
      } else {
        _holidays.removeWhere((h) => h.date.year == year);
      }
      _holidays.addAll(newHolidays);
      notifyListeners();
    }
  }

  List<HolidayModel> holidaysForDay(DateTime day) {
    return _holidays.where((h) =>
      h.date.year == day.year &&
      h.date.month == day.month &&
      h.date.day == day.day
    ).toList();
  }

  /// Called after a successful data load to push widget updates.
  /// Overridable in subclasses for testing widget-update side effects.
  @protected
  void triggerWidgetUpdates() {
    _updateHomeWidget();
    _updateMonthlyWidget();
  }

  Future<void> loadEvents({DateTime? start, DateTime? end}) async {
    _isLoading = true;
    notifyListeners();
    try {
      String query = '';
      if (start != null) query += 'start=${start.toIso8601String()}&';
      if (end != null) query += 'end=${end.toIso8601String()}&';
      final res = await _api.get('/events${query.isNotEmpty ? "?$query" : ""}');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final parsed = list.map((j) => EventModel.fromJson(j)).toList();
        // Filter out events whose deferred delete is still pending (dw3):
        // the server still returns them, but the user has locally deleted them.
        if (_pendingDeleteIds.isNotEmpty) {
          _events = parsed.where((e) => !_pendingDeleteIds.contains(e.id)).toList();
        } else {
          _events = parsed;
        }
        _error = null;
        _isLoading = false;
        notifyListeners();
        triggerWidgetUpdates();
      } else {
        _error = 'Failed to load events (status ${res.statusCode})';
        _isLoading = false;
        notifyListeners();
        debugPrint('loadEvents: non-200 response (${res.statusCode})');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('loadEvents: exception: $e');
    }
  }

  Future<void> loadGroupEvents({DateTime? start, DateTime? end}) async {
    String query = '';
    if (start != null) query += 'start=${start.toIso8601String()}&';
    if (end != null) query += 'end=${end.toIso8601String()}&';
    final res = await _api.get(
      '/family/calendars${query.isNotEmpty ? "?$query" : ""}',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      _groupEvents = [];
      for (final member in data) {
        if (member['calendars'] != null) {
          for (final cal in member['calendars']) {
            if (cal['events'] != null) {
              for (final evt in cal['events']) {
                evt['calendar'] = {'name': cal['name'], 'color': cal['color']};
                _groupEvents.add(EventModel.fromJson(evt));
              }
            }
          }
        }
      }
      notifyListeners();
      _updateHomeWidget();
      _updateMonthlyWidget();
    }
  }

  Future<bool> createEvent(Map<String, dynamic> data) async {
    final res = await _api.post('/events', data);
    if (res.statusCode == 201) {
      await loadEvents();
      return true;
    }
    return false;
  }

  String _withEditModeQuery(String path, {String? editMode, String? instanceDate}) {
    final queryParams = <String, String>{};
    if (editMode != null) queryParams['editMode'] = editMode;
    if (instanceDate != null) queryParams['instanceDate'] = instanceDate;
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$path${queryString.isNotEmpty ? "?$queryString" : ""}';
  }

  Future<bool> updateEvent(
    String id,
    Map<String, dynamic> data, {
    String? editMode,
    String? instanceDate,
  }) async {
    final path = _withEditModeQuery('/events/$id', editMode: editMode, instanceDate: instanceDate);
    final res = await _api.put(path, data);
    if (res.statusCode == 200) {
      await loadEvents();
      return true;
    }
    return false;
  }

  Future<bool> deleteEvent(
    String id, {
    String? editMode,
    String? instanceDate,
  }) async {
    final path = _withEditModeQuery('/events/$id', editMode: editMode, instanceDate: instanceDate);
    final res = await _api.delete(path);
    if (res.statusCode == 204) {
      await loadEvents();
      return true;
    }
    return false;
  }

  Future<List<EventModel>> searchEvents(String query) async {
    final res = await _api.get('/events/search?q=$query');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((j) => EventModel.fromJson(j)).toList();
    }
    return [];
  }

  // ─── Task methods ───

  Future<void> loadTasks({DateTime? start, DateTime? end, String? status, String? eventId}) async {
    String query = '';
    if (start != null) query += 'start=${start.toIso8601String()}&';
    if (end != null) query += 'end=${end.toIso8601String()}&';
    if (status != null) query += 'status=$status&';
    if (eventId != null) query += 'eventId=$eventId&';
    final res = await _api.get('/tasks${query.isNotEmpty ? "?$query" : ""}');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      _tasks = list.map((j) => TaskModel.fromJson(j)).toList();
      notifyListeners();
    }
  }

  Future<bool> createTask(Map<String, dynamic> data) async {
    final res = await _api.post('/tasks', data);
    if (res.statusCode == 201) {
      await loadTasks();
      _updateHomeWidget();
      _updateMonthlyWidget();
      return true;
    }
    return false;
  }

  Future<bool> updateTask(
    String id,
    Map<String, dynamic> data, {
    String? editMode,
    String? instanceDate,
  }) async {
    final path = _withEditModeQuery('/tasks/$id', editMode: editMode, instanceDate: instanceDate);
    final res = await _api.put(path, data);
    if (res.statusCode == 200) {
      await loadTasks();
      _updateHomeWidget();
      _updateMonthlyWidget();
      return true;
    }
    return false;
  }

  Future<bool> deleteTask(
    String id, {
    String? editMode,
    String? instanceDate,
  }) async {
    final path = _withEditModeQuery('/tasks/$id', editMode: editMode, instanceDate: instanceDate);
    final res = await _api.delete(path);
    if (res.statusCode == 204) {
      await loadTasks();
      _updateHomeWidget();
      _updateMonthlyWidget();
      return true;
    }
    return false;
  }

  Future<bool> toggleTaskComplete(String id, {String? instanceDate}) async {
    final path = _withEditModeQuery('/tasks/$id/complete', instanceDate: instanceDate);
    final res = await _api.patch(path);
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final updated = TaskModel.fromJson(json);
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx >= 0) {
        _tasks[idx] = updated;
        notifyListeners();
      }
      _updateHomeWidget();
      _updateMonthlyWidget();
      return true;
    }
    return false;
  }

  Future<bool> linkTaskToEvent(String taskId, String? eventId) async {
    final res = await _api.patch('/tasks/$taskId/link', {'eventId': eventId});
    if (res.statusCode == 200) {
      await loadTasks();
      _updateHomeWidget();
      return true;
    }
    return false;
  }

  List<TaskModel> tasksForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _tasks.where((t) {
      final date = t.scheduledDate ?? t.dueDate;
      if (date == null) return false;
      return date.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
             date.isBefore(dayEnd);
    }).toList();
  }

  List<TaskModel> tasksForEvent(String eventId) {
    return _tasks.where((t) => t.eventId == eventId).toList();
  }

  List<TaskModel> get unscheduledTasks {
    return _tasks.where((t) => t.scheduledDate == null && t.dueDate == null && t.isTodo).toList();
  }

  // ─── Deferred delete (#114) ───

  /// Removes the event from the visible list immediately (optimistic) and
  /// schedules the real API delete after [delay].
  ///
  /// If another deferred delete is already pending for a different event,
  /// both are tracked independently -- the second call does not cancel the
  /// first (dw5 / dissent-3).
  ///
  /// The [delay] parameter exists so tests can inject a custom duration,
  /// but the default 5-second grace period is the product requirement.
  void deleteEventDeferred(String id, {Duration delay = const Duration(seconds: 5)}) {
    // Stash the event and its original index for position-preserving undo
    // (spec1 rework: issue #114 같은 자리로).
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _pendingDeleteEvents[id] = (event: _events[idx], index: idx);
      _events.removeAt(idx);
    }

    // Cancel any existing timer for the same id (idempotency).
    _pendingDeleteTimers[id]?.cancel();

    // Schedule the actual API delete. The callback is async so we can await
    // deleteEvent and handle failures (qa1 rework).
    _pendingDeleteTimers[id] = Timer(delay, () async {
      _pendingDeleteTimers.remove(id);
      // Keep _pendingDeleteEvents[id] during the API call so that
      // _pendingDeleteIds still filters the event from loadEvents results
      // (qa1 rework: in-flight filtering).
      try {
        final success = await deleteEvent(id);
        if (success) {
          // API delete succeeded -- clean up stash.
          _pendingDeleteEvents.remove(id);
        } else {
          // API returned non-204 -- restore the event (qa1 rework).
          _restoreStashedEvent(id);
        }
      } catch (e) {
        // Network error or other exception -- restore the event (qa1 rework).
        _restoreStashedEvent(id);
        debugPrint('deleteEventDeferred: API delete failed for $id: $e');
      }
    });

    notifyListeners();
  }

  /// Restores a stashed event to [_events] at its original position (clamped)
  /// and notifies listeners. Used by the timer callback on API failure.
  void _restoreStashedEvent(String id) {
    final stash = _pendingDeleteEvents.remove(id);
    if (stash != null) {
      final insertIdx = stash.index.clamp(0, _events.length);
      _events.insert(insertIdx, stash.event);
      notifyListeners();
    }
  }

  /// Cancels a pending deferred delete and restores the event to the
  /// visible list. If the event is not pending, this is a no-op.
  void undoDelete(String id) {
    final timer = _pendingDeleteTimers.remove(id);
    timer?.cancel();

    final stash = _pendingDeleteEvents.remove(id);
    if (stash != null) {
      // Insert at the original position (clamped to current list bounds)
      // so the event returns to the same slot (spec1 rework: issue #114
      // 같은 자리로).
      final insertIdx = stash.index.clamp(0, _events.length);
      _events.insert(insertIdx, stash.event);
    }

    notifyListeners();
  }

  /// Whether there is a pending deferred delete for the given event id.
  /// Returns true during both the grace period and the in-flight API delete.
  bool hasPendingDelete(String id) => _pendingDeleteEvents.containsKey(id);

  @override
  void dispose() {
    // Cancel all pending timers to avoid calling notifyListeners on a
    // disposed ChangeNotifier (dissent-4).
    for (final timer in _pendingDeleteTimers.values) {
      timer.cancel();
    }
    _pendingDeleteTimers.clear();
    _pendingDeleteEvents.clear();
    super.dispose();
  }
}
