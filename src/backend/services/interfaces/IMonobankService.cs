using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IMonobankService
{
    Task<ServiceResult<BankIntegrationResponse>> SetupAsync(SetupBankIntegrationRequest request, Guid userId);
    Task<ServiceResult<List<TransactionResponse>>> SyncAsync(SyncBankRequest request, Guid userId);
    Task<ServiceResult<List<BankIntegrationResponse>>> GetIntegrationsAsync(Guid userId);
}
