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
      id: json['id'],
      name: json['name'],
      color: json['color'],
      emoji: json['emoji'],
      userId: json['userId'],
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
