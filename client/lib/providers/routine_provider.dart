import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../services/api_service.dart';

class RoutineProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<RoutineModel> _routines = [];
  List<RoutineGroupModel> _groups = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  List<RoutineModel> get routines => _routines;
  List<RoutineGroupModel> get groups => _groups;
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;

  /// Routines grouped by group. null key = ungrouped.
  Map<String?, List<RoutineModel>> get groupedRoutines {
    final map = <String?, List<RoutineModel>>{};
    for (final r in _routines) {
      map.putIfAbsent(r.groupId, () => []).add(r);
    }
    return map;
  }

  int get completedCount => _routines.where((r) => r.completed).length;
  int get totalCount => _routines.length;

  Future<void> loadRoutines({DateTime? date}) async {
    _isLoading = true;
    notifyListeners();

    if (date != null) _selectedDate = date;
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final res = await _api.get('/routines?date=$dateStr');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      _routines = list.map((j) => RoutineModel.fromJson(j)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadGroups() async {
    final res = await _api.get('/routines/groups');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      _groups = list.map((j) => RoutineGroupModel.fromJson(j)).toList();
      notifyListeners();
    }
  }

  Future<bool> createRoutine(Map<String, dynamic> data) async {
    final res = await _api.post('/routines', data);
    if (res.statusCode == 201) {
      await loadRoutines();
      return true;
    }
    return false;
  }

  Future<bool> updateRoutine(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/routines/$id', data);
    if (res.statusCode == 200) {
      await loadRoutines();
      return true;
    }
    return false;
  }

  Future<bool> deleteRoutine(String id) async {
    final res = await _api.delete('/routines/$id');
    if (res.statusCode == 204) {
      await loadRoutines();
      return true;
    }
    return false;
  }

  Future<bool> toggleComplete(String routineId) async {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final res = await _api.post('/routines/$routineId/complete', {'date': dateStr});
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final idx = _routines.indexWhere((r) => r.id == routineId);
      if (idx >= 0) {
        final old = _routines[idx];
        _routines[idx] = RoutineModel(
          id: old.id,
          name: old.name,
          time: old.time,
          repeatDays: old.repeatDays,
          groupId: old.groupId,
          groupName: old.groupName,
          sortOrder: old.sortOrder,
          completed: json['completed'] ?? false,
          completedAt: json['completedAt'] != null
              ? DateTime.parse(json['completedAt'])
              : null,
        );
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  Future<bool> createGroup(Map<String, dynamic> data) async {
    final res = await _api.post('/routines/groups', data);
    if (res.statusCode == 201) {
      await loadGroups();
      return true;
    }
    return false;
  }

  Future<bool> updateGroup(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/routines/groups/$id', data);
    if (res.statusCode == 200) {
      await loadGroups();
      return true;
    }
    return false;
  }

  Future<bool> deleteGroup(String id) async {
    final res = await _api.delete('/routines/groups/$id');
    if (res.statusCode == 204) {
      await loadGroups();
      await loadRoutines();
      return true;
    }
    return false;
  }
}
