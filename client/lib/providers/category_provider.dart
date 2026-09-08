import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class CategoryProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  Set<String> _selectedCategoryIds = {};

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  Set<String> get selectedCategoryIds => _selectedCategoryIds;

  CategoryModel? get defaultCategory {
    try {
      return _categories.firstWhere((c) => c.isDefault);
    } catch (_) {
      return _categories.isNotEmpty ? _categories.first : null;
    }
  }

  bool get isAllCategoriesSelected =>
      _categories.isEmpty || _selectedCategoryIds.length == _categories.length;

  CategoryModel? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void toggleCategory(String categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      if (_selectedCategoryIds.length > 1) {
        _selectedCategoryIds.remove(categoryId);
      }
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  void selectAllCategories() {
    _selectedCategoryIds = _categories.map((c) => c.id).toSet();
    notifyListeners();
  }

  bool isCategoryVisible(String? categoryId) {
    if (_selectedCategoryIds.isEmpty) return true;
    if (categoryId == null) return true;
    return _selectedCategoryIds.contains(categoryId);
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/categories');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _categories = list.map((j) => CategoryModel.fromJson(j)).toList();
        // Initialize all categories as selected if first load
        if (_selectedCategoryIds.isEmpty) {
          _selectedCategoryIds = _categories.map((c) => c.id).toSet();
        } else {
          // Keep only valid IDs
          final validIds = _categories.map((c) => c.id).toSet();
          _selectedCategoryIds = _selectedCategoryIds.intersection(validIds);
          // Add new categories
          for (final c in _categories) {
            _selectedCategoryIds.add(c.id);
          }
        }
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createCategory({
    required String name,
    required String color,
    String? emoji,
  }) async {
    final res = await _api.post('/categories', {
      'name': name,
      'color': color,
      if (emoji != null && emoji.isNotEmpty) 'emoji': emoji,
    });
    if (res.statusCode == 201) {
      await loadCategories();
      return true;
    }
    return false;
  }

  Future<bool> updateCategory(
    String id, {
    String? name,
    String? color,
    String? emoji,
    int? sortOrder,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (color != null) data['color'] = color;
    if (emoji != null) data['emoji'] = emoji.isEmpty ? null : emoji;
    if (sortOrder != null) data['sortOrder'] = sortOrder;

    final res = await _api.put('/categories/$id', data);
    if (res.statusCode == 200) {
      await loadCategories();
      return true;
    }
    return false;
  }

  Future<bool> deleteCategory(String id) async {
    final res = await _api.delete('/categories/$id');
    if (res.statusCode == 204) {
      await loadCategories();
      return true;
    }
    return false;
  }
}
