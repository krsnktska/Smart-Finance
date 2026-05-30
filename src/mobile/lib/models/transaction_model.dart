import 'package:mobile/models/category_model.dart';

enum TransactionType { expense, income }

enum SpecialType { upcoming, subscription, repetitive, credit, debt }

class TransactionModel {
  final String id;
  final TransactionType type;
  final SpecialType? specialType;
  final double value;
  final DateTime occurredAt;
  final String name;
  final String? description;
  final String currency;
  final String accountId;
  final List<CategoryModel> categories;

  TransactionModel({
    required this.id,
    required this.type,
    this.specialType,
    required this.value,
    required this.occurredAt,
    required this.name,
    this.description,
    required this.currency,
    required this.accountId,
    required this.categories,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      type: _parseTransactionType(json['type']),
      specialType: json['specialType'] != null
          ? _parseSpecialType(json['specialType'])
          : null,
      value: (json['value'] as num).toDouble(),

      occurredAt: DateTime.parse(json['occurredAt'] as String).toLocal(),
      name: json['name'] as String,
      description: json['description'] as String?,
      currency: json['currency'] as String,
      accountId: json['accountId'] as String,
      categories: (json['categories'] as List<dynamic>)
          .map((cat) => CategoryModel.fromJson(cat as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': _transactionTypeToString(type),
      'specialType': specialType != null
          ? _specialTypeToString(specialType!)
          : null,
      'value': value,
      'occurredAt': occurredAt.toIso8601String(),
      'name': name,
      'description': description,
      'currency': currency,
      'accountId': accountId,
      'categories': categories.map((cat) => cat.toJson()).toList(),
    };
  }

  static TransactionType _parseTransactionType(dynamic value) {
    if (value is int) {
      if (value >= 0 && value < TransactionType.values.length) {
        return TransactionType.values[value];
      }
      return TransactionType.expense;
    }

    final String strValue = value.toString().toLowerCase();
    return TransactionType.values.firstWhere(
      (e) => e.toString().split('.').last == strValue,
      orElse: () => TransactionType.expense,
    );
  }

  static String _transactionTypeToString(TransactionType type) {
    return type.toString().split('.').last;
  }

  static SpecialType _parseSpecialType(dynamic value) {
    if (value is int) {
      if (value >= 0 && value < SpecialType.values.length) {
        return SpecialType.values[value];
      }
      return SpecialType.upcoming;
    }

    final String strValue = value.toString().toLowerCase();
    return SpecialType.values.firstWhere(
      (e) => e.toString().split('.').last == strValue,
      orElse: () => SpecialType.upcoming,
    );
  }

  static String _specialTypeToString(SpecialType type) {
    return type.toString().split('.').last;
  }
}
