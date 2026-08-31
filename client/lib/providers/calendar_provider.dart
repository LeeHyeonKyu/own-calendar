import 'dart:convert';
import 'package:flutter/material.dart';
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

  List<CalendarModel> get calendars => _calendars;
  List<EventModel> get events => _events;
  List<EventModel> get familyEvents => _familyEvents;
  List<EventModel> get allVisibleEvents =>
      _showFamilyEvents ? [..._events, ..._familyEvents] : _events;
  bool get isLoading => _isLoading;
  bool get showFamilyEvents => _showFamilyEvents;

  void toggleFamilyEvents() {
    _showFamilyEvents = !_showFamilyEvents;
    notifyListeners();
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
