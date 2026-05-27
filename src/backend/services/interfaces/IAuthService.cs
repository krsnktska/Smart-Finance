using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IAuthService
{
    Task<ServiceResult<AuthResponse>> RegisterAsync(RegisterRequest request);
    Task<ServiceResult<AuthResponse>> LoginAsync(LoginRequest request);
}
