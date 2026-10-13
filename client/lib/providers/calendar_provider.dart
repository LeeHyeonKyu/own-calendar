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
  final ApiService _api = ApiService();
  List<CalendarModel> _calendars = [];
  List<EventModel> _events = [];
  List<EventModel> _groupEvents = [];
  Set<String> _groupCalendarIds = {};
  List<HolidayModel> _holidays = [];
  List<TaskModel> _tasks = [];
  bool _isLoading = false;
  bool _showGroupEvents = true;

  /// DB categories loaded from /api/categories
  List<CategoryModel> _categories = [];

  /// Category IDs the user has chosen to hide. Persisted in SharedPreferences.
  Set<String> _hiddenCategoryIds = {};

  /// Whether to hide events/tasks with no categoryId ("uncategorized").
  bool _hideUncategorized = false;

  static const _kHiddenCategoryIds = 'hidden_category_ids';
  static const _kHideUncategorized = 'hide_uncategorized';

  List<CalendarModel> get calendars => _calendars;
  List<EventModel> get events => _events;
  List<EventModel> get groupEvents => _groupEvents;
  List<HolidayModel> get holidays => _holidays;
  List<CategoryModel> get categories => _categories;
  Set<String> get hiddenCategoryIds => _hiddenCategoryIds;
  bool get hideUncategorized => _hideUncategorized;

  List<TaskModel> get tasks {
    var result = _showGroupEvents
        ? _tasks
        : _tasks.where((t) => !_groupCalendarIds.contains(t.calendarId)).toList();
    if (_hiddenCategoryIds.isNotEmpty || _hideUncategorized) {
      result = result.where((t) {
        if (t.categoryId == null) return !_hideUncategorized;
        return !_hiddenCategoryIds.contains(t.categoryId);
      }).toList();
    }
    return result;
  }

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
  bool get showGroupEvents => _showGroupEvents;
  bool get isAllCategoriesSelected =>
      _hiddenCategoryIds.isEmpty && !_hideUncategorized;

  void toggleGroupEvents() {
    _showGroupEvents = !_showGroupEvents;
    notifyListeners();
  }

  /// Toggle visibility of a specific DB category by its id.
  void toggleCategoryVisibility(String categoryId) {
    if (_hiddenCategoryIds.contains(categoryId)) {
      _hiddenCategoryIds.remove(categoryId);
    } else {
      _hiddenCategoryIds.add(categoryId);
    }
    _saveHiddenCategories();
    notifyListeners();
  }

  /// Toggle visibility of uncategorized events/tasks.
  void toggleUncategorized() {
    _hideUncategorized = !_hideUncategorized;
    _saveHiddenCategories();
    notifyListeners();
  }

  /// Show all categories (clear hidden set).
  void selectAllCategories() {
    _hiddenCategoryIds.clear();
    _hideUncategorized = false;
    _saveHiddenCategories();
    notifyListeners();
  }

  /// Load DB categories from the server and restore hidden state from prefs.
  Future<void> loadCategories() async {
    try {
      final res = await _api.get('/categories');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _categories = list.map((j) => CategoryModel.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    // Restore hidden state from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final hiddenJson = prefs.getString(_kHiddenCategoryIds);
      if (hiddenJson != null) {
        final decoded = jsonDecode(hiddenJson) as List;
        final validIds = _categories.map((c) => c.id).toSet();
        _hiddenCategoryIds = decoded.cast<String>().where((id) => validIds.contains(id)).toSet();
      }
      _hideUncategorized = prefs.getBool(_kHideUncategorized) ?? false;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _saveHiddenCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kHiddenCategoryIds, jsonEncode(_hiddenCategoryIds.toList()));
      await prefs.setBool(_kHideUncategorized, _hideUncategorized);
    } catch (_) {}
  }

  /// Check if a specific category is visible (not hidden).
  bool isCategoryVisible(String categoryId) {
    return !_hiddenCategoryIds.contains(categoryId);
  }

  /// Find a category by id.
  CategoryModel? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
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

  Future<void> loadHolidays({required int year, int? month}) async {
    String query = 'year=$year';
    if (month != null) query += '&month=$month';
    final res = await _api.get('/holidays/holidays?$query');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      _holidays = list.map((j) => HolidayModel.fromJson(j as Map<String, dynamic>)).toList();
      notifyListeners();
    }
  }

  List<HolidayModel> holidaysForDay(DateTime day) {
    return _holidays.where((h) =>
      h.date.year == day.year && h.date.month == day.month && h.date.day == day.day
    ).toList();
  }

  Future<void> loadCalendars() async {
    final res = await _api.get('/calendars');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      _calendars = list.map((j) => CalendarModel.fromJson(j)).toList();
      notifyListeners();
    }
  }

  Future<void> loadEvents({DateTime? start, DateTime? end}) async {
    _isLoading = true;
    notifyListeners();
    String query = '';
    if (start != null) query += 'start=${start.toIso8601String()}&';
    if (end != null) query += 'end=${end.toIso8601String()}&';
    final res = await _api.get('/events${query.isNotEmpty ? "?$query" : ""}');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      _events = list.map((j) => EventModel.fromJson(j)).toList();
    }
    _isLoading = false;
    notifyListeners();
    _updateHomeWidget();
    _updateMonthlyWidget();
  }

  Future<void> loadGroupEvents({DateTime? start, DateTime? end}) async {
    String query = '';
    if (start != null) query += 'start=${start.toIso8601String()}&';
    if (end != null) query += 'end=${end.toIso8601String()}&';
    final res = await _api.get(
      '/groups/calendars${query.isNotEmpty ? "?$query" : ""}',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      _groupEvents = [];
      _groupCalendarIds = {};
      for (final member in data) {
        if (member['calendars'] != null) {
          for (final cal in member['calendars']) {
            _groupCalendarIds.add(cal['id'] as String);
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
      final json = jsonDecode(res.body);
      final updated = TaskModel.fromJson(json);
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx >= 0) {
        _tasks[idx] = updated;
        notifyListeners();
      } else {
        await loadTasks();
      }
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
}
