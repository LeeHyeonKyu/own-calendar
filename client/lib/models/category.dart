import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String color;
  final String? emoji;
  final bool isDefault;
  final int sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.color,
    this.emoji,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      color: json['color'] ?? '#9E9E9E',
      emoji: json['emoji'],
      isDefault: json['isDefault'] ?? false,
      sortOrder: json['sortOrder'] ?? 0,
    );
  }

  Color get colorValue {
    try {
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF9E9E9E);
    }
  }

  String get displayName {
    if (emoji != null && emoji!.isNotEmpty) {
      return '$emoji $name';
    }
    return name;
  }

  /// 12 preset colors for the category color picker
  static const presetColors = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // DeepPurple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#CDDC39', // Lime
    '#FF9800', // Orange
    '#795548', // Brown
  ];

  static const presetColorNames = [
    'Red',
    'Pink',
    'Purple',
    'DeepPurple',
    'Indigo',
    'Blue',
    'Cyan',
    'Teal',
    'Green',
    'Lime',
    'Orange',
    'Brown',
  ];
}
