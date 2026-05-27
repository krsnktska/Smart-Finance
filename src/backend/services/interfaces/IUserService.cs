using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IUserService
{
    Task<ServiceResult<UserResponse>> GetByIdAsync(Guid userId);
    Task<ServiceResult<UserResponse>> UpdateAsync(Guid userId, UpdateUserRequest request);
}
