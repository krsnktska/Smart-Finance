namespace SmartFinance.Models.Responses;

public record ReceiptItemResponse(
    Guid Id,
    string Name,
    decimal Quantity,
    string? Unit,
    decimal UnitPrice,
    decimal TotalPrice
);
