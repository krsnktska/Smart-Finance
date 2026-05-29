namespace SmartFinance.Models.Requests;

public record SetupBankIntegrationRequest(
    string ApiToken,
    Guid AccountId,
    string? BankAccountId
);
