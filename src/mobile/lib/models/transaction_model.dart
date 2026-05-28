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
      id: json['id'],
      type: _parseTransactionType(json['type']),
      specialType: json['specialType'] != null
          ? _parseSpecialType(json['specialType'])
          : null,
      value: (json['value'] as num).toDouble(),
      occurredAt: DateTime.parse(json['occurredAt']),
      name: json['name'],
      description: json['description'],
      currency: json['currency'],
      accountId: json['accountId'],
      categories: (json['categories'] as List<dynamic>)
          .map((cat) => CategoryModel.fromJson(cat))
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

  static TransactionType _parseTransactionType(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.toString().split('.').last == value.toLowerCase(),
    );
  }

  static String _transactionTypeToString(TransactionType type) {
    return type.toString().split('.').last;
  }

  static SpecialType _parseSpecialType(String value) {
    return SpecialType.values.firstWhere(
      (e) => e.toString().split('.').last == value.toLowerCase(),
    );
  }

  static String _specialTypeToString(SpecialType type) {
    return type.toString().split('.').last;
  }
}
