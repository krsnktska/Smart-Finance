namespace SmartFinance.Models.Responses;

public record BankIntegrationResponse(
    Guid Id,
    string BankType,
    Guid AccountId,
    string? BankAccountId,
    DateTimeOffset? LastSyncedAt
);
