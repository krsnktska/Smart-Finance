using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IGmailIntegrationService
{
    string GetAuthorizationUrl(Guid userId);
    Task<ServiceResult<GmailIntegrationResponse>> HandleCallbackAsync(string code, Guid userId, Guid accountId);
    Task<ServiceResult<List<ReceiptScanResponse>>> ScanInboxAsync(Guid userId, Guid accountId);
    Task<GmailIntegrationResponse?> GetStatusAsync(Guid userId);
}
