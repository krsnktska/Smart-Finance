namespace SmartFinance.Models.Responses;

public record CategorySpendingResponse(
    Guid? CategoryId,
    string Name,
    string? Color,
    string? Emoji,
    decimal TotalAmount,
    int TransactionCount);
