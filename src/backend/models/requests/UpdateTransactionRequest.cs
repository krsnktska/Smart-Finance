namespace SmartFinance.Models.Requests;

public record UpdateTransactionRequest(
    TransactionType? Type,
    SpecialType? SpecialType,
    decimal? Value,
    DateTimeOffset? OccurredAt,
    string? Name,
    string? Description,
    string? Currency,
    List<Guid>? CategoryIds);
