using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface ITransactionService
{
    Task<ServiceResult<List<TransactionResponse>>> GetAllAsync(Guid accountId, Guid userId);
    Task<ServiceResult<TransactionResponse>> GetByIdAsync(Guid id, Guid userId);
    Task<ServiceResult<TransactionResponse>> CreateAsync(CreateTransactionRequest request, Guid userId);
    Task<ServiceResult<TransactionResponse>> UpdateAsync(Guid id, Guid userId, UpdateTransactionRequest request);
    Task<ServiceResult> DeleteAsync(Guid id, Guid userId);
}
