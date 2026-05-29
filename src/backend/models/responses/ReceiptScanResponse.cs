namespace SmartFinance.Models.Responses;

public record ReceiptScanResponse(
    TransactionResponse Transaction,
    List<ReceiptItemResponse> Items
);
