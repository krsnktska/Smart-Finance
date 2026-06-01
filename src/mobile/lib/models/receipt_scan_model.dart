import 'package:mobile/models/receipt_item_model.dart';
import 'package:mobile/models/transaction_model.dart';

class ReceiptScanModel {
  final TransactionModel transaction;
  final List<ReceiptItemModel> items;

  ReceiptScanModel({required this.transaction, required this.items});

  factory ReceiptScanModel.fromJson(Map<String, dynamic> json) {
    return ReceiptScanModel(
      transaction: TransactionModel.fromJson(
        json['transaction'] as Map<String, dynamic>,
      ),
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => ReceiptItemModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
