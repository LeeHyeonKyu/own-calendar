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
