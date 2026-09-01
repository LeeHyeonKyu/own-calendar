import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../models/calendar.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class CalendarProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<CalendarModel> _calendars = [];
  List<EventModel> _events = [];
  List<EventModel> _familyEvents = [];
  bool _isLoading = false;
  bool _showFamilyEvents = true;
  Set<String> _selectedCategories = {
    'WORK', 'PERSONAL', 'FAMILY', 'HEALTH', 'SOCIAL', 'FINANCE', 'OTHER',
  };

  List<CalendarModel> get calendars => _calendars;
  List<EventModel> get events => _events;
  List<EventModel> get familyEvents => _familyEvents;
  List<EventModel> get allVisibleEvents {
    final merged = _showFamilyEvents ? [..._events, ..._familyEvents] : _events;
    if (_selectedCategories.length == EventModel.categoryLabels.length) {
      return merged;
    }
    return merged.where((e) => _selectedCategories.contains(e.category)).toList();
  }
  bool get isLoading => _isLoading;
  bool get showFamilyEvents => _showFamilyEvents;
  Set<String> get selectedCategories => _selectedCategories;
  bool get isAllCategoriesSelected =>
      _selectedCategories.length == EventModel.categoryLabels.length;

  void toggleFamilyEvents() {
    _showFamilyEvents = !_showFamilyEvents;
    notifyListeners();
  }

  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      if (_selectedCategories.length > 1) {
        _selectedCategories.remove(category);
      }
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }

  void selectAllCategories() {
    _selectedCategories = {
      'WORK', 'PERSONAL', 'FAMILY', 'HEALTH', 'SOCIAL', 'FINANCE', 'OTHER',
    };
    notifyListeners();
  }

  Future<void> _updateMonthlyWidget() async {
    try {
      final now = DateTime.now();
      // Build events map: day number -> list of event data
      final Map<String, List<Map<String, dynamic>>> eventsMap = {};

      final allEvents = [..._events, ..._familyEvents];
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
            'isFamily': _familyEvents.contains(event),
          });
        }
      }

      final monthlyData = {
        'year': now.year,
        'month': now.month,
        'events': eventsMap,
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

      await HomeWidget.saveWidgetData('todayEvents', jsonEncode(widgetData));
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

  Future<void> loadFamilyEvents({DateTime? start, DateTime? end}) async {
    String query = '';
    if (start != null) query += 'start=${start.toIso8601String()}&';
    if (end != null) query += 'end=${end.toIso8601String()}&';
    final res = await _api.get(
      '/family/calendars${query.isNotEmpty ? "?$query" : ""}',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      _familyEvents = [];
      for (final member in data) {
        if (member['calendars'] != null) {
          for (final cal in member['calendars']) {
            if (cal['events'] != null) {
              for (final evt in cal['events']) {
                evt['calendar'] = {'name': cal['name'], 'color': cal['color']};
                _familyEvents.add(EventModel.fromJson(evt));
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

  Future<bool> updateEvent(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/events/$id', data);
    if (res.statusCode == 200) {
      await loadEvents();
      return true;
    }
    return false;
  }

  Future<bool> deleteEvent(String id) async {
    final res = await _api.delete('/events/$id');
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
}
