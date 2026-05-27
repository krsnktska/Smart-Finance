namespace SmartFinance.Models.Responses;

public record TransactionResponse(
    Guid Id,
    TransactionType Type,
    SpecialType? SpecialType,
    decimal Value,
    DateTimeOffset OccurredAt,
    string Name,
    string? Description,
    string Currency,
    Guid AccountId,
    List<CategoryResponse> Categories);
