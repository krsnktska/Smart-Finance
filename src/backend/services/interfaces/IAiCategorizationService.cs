using SmartFinance.Models;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IAiCategorizationService
{
    Task<List<Guid>> CategorizeItemsAsync(List<ParsedReceiptItem> items, List<CategoryResponse> availableCategories);
}
