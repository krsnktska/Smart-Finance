using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface ICategoryService
{
    Task<List<CategoryResponse>> GetAllAsync(Guid userId);
    Task<ServiceResult<CategoryResponse>> GetByIdAsync(Guid id, Guid userId);
    Task<CategoryResponse> CreateAsync(Guid userId, CreateCategoryRequest request);
    Task<ServiceResult<CategoryResponse>> UpdateAsync(Guid id, Guid userId, UpdateCategoryRequest request);
    Task<ServiceResult> DeleteAsync(Guid id, Guid userId);
}
