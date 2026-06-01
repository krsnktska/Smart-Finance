class ReceiptItemModel {
  final String id;
  final String name;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double totalPrice;

  ReceiptItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    this.unit,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String?,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
    );
  }
}
