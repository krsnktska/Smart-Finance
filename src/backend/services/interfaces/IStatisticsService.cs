using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IStatisticsService
{
    Task<ServiceResult<AccountSummaryResponse>> GetSummaryAsync(
        Guid accountId, Guid userId, DateTimeOffset? from, DateTimeOffset? to);

    Task<ServiceResult<List<CategorySpendingResponse>>> GetByCategoryAsync(
        Guid accountId, Guid userId, DateTimeOffset? from, DateTimeOffset? to);
}
