namespace SmartFinance.Models.Requests;

public record SyncBankRequest(
    Guid IntegrationId,
    DateTimeOffset From,
    DateTimeOffset To
);
