import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String color;
  final String? emoji;
  final String? userId;

  CategoryModel({
    required this.id,
    required this.name,
    required this.color,
    this.emoji,
    this.userId,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      // 📝 Проверяем оба ключа: id и categoryId. Если обоих нет — ставим пустую строку.
      id: (json['id'] ?? json['categoryId'] ?? '') as String,
      name: (json['name'] ?? 'Без названия') as String,
      color: (json['color'] ?? '#808080') as String,
      emoji: json['emoji'] as String?,
      userId: json['userId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'emoji': emoji,
      'userId': userId,
    };
  }

  Color get categoryColor {
    try {
      final hexColor = color.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      } else if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing color: $e');
      }
    }
    return Colors.grey;
  }
}
