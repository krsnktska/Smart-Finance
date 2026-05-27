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
      categoryId: json['categoryId'],
      name: json['name'],
      color: json['color'],
      emoji: json['emoji'],
      totalAmount: (json['totalAmount'] as num).toDouble(),
      transactionCount: json['transactionCount'],
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
