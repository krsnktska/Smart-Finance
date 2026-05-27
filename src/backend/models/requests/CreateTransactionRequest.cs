using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record CreateTransactionRequest(
    [Required] TransactionType Type,
    SpecialType? SpecialType,
    [Required][Range(0.01, double.MaxValue)] decimal Value,
    [Required] DateTimeOffset OccurredAt,
    [Required] string Name,
    string? Description,
    [Required] string Currency,
    [Required] Guid AccountId,
    List<Guid>? CategoryIds);
