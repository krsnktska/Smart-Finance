namespace SmartFinance.Models.Responses;

public record GmailIntegrationResponse(
    string GmailAddress,
    DateTimeOffset? LastScannedAt
);
