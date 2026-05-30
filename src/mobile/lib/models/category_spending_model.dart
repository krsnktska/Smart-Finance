class CategorySpendingModel {
  final String? categoryId;
  final String name;
  final String? color;
  final String? emoji;
  final double totalAmount;
  final int transactionCount;

  CategorySpendingModel({
    this.categoryId,
    required this.name,
    this.color,
    this.emoji,
    required this.totalAmount,
    required this.transactionCount,
  });

  factory CategorySpendingModel.fromJson(Map<String, dynamic> json) {
    return CategorySpendingModel(
      categoryId: (json['categoryId'] ?? json['id']) as String?,
      name: (json['name'] ?? 'Без названия') as String,
      color: json['color'] as String?,
      emoji: json['emoji'] as String?,
      totalAmount: (json['totalAmount'] as num? ?? 0.0).toDouble(),
      transactionCount: (json['transactionCount'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'name': name,
      'color': color,
      'emoji': emoji,
      'totalAmount': totalAmount,
      'transactionCount': transactionCount,
    };
  }
}
