using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IAccountService
{
    Task<List<AccountResponse>> GetAllAsync(Guid userId);
    Task<ServiceResult<AccountResponse>> GetByIdAsync(Guid id, Guid userId);
    Task<AccountResponse> CreateAsync(Guid userId, CreateAccountRequest request);
    Task<ServiceResult<AccountResponse>> UpdateAsync(Guid id, Guid userId, UpdateAccountRequest request);
    Task<ServiceResult> DeleteAsync(Guid id, Guid userId);
}
