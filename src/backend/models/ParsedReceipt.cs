namespace SmartFinance.Models;

public record ParsedReceiptItem(
    string Name,
    decimal Quantity,
    string? Unit,
    decimal UnitPrice,
    decimal TotalPrice
);

public record ParsedReceipt(
    string StoreName,
    DateTimeOffset OccurredAt,
    decimal Total,
    string Currency,
    List<ParsedReceiptItem> Items
);
