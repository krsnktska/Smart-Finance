using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class StatisticsService(SmartFinanceDbContext context) : IStatisticsService
{
    public async Task<ServiceResult<AccountSummaryResponse>> GetSummaryAsync(
        Guid accountId, Guid userId, DateTimeOffset? from, DateTimeOffset? to)
    {
        var account = await context.Accounts
            .FirstOrDefaultAsync(a => a.Id == accountId && a.UserId == userId);

        if (account is null) return ServiceResult<AccountSummaryResponse>.NotFound();

        var transactions = await context.Transactions
            .Where(t => t.AccountId == accountId)
            .Where(t => !from.HasValue || t.OccurredAt >= from.Value)
            .Where(t => !to.HasValue || t.OccurredAt <= to.Value)
            .ToListAsync();

        var totalIncome = transactions
            .Where(t => t.Type == TransactionType.Income)
            .Sum(t => t.Value);

        var totalExpense = transactions
            .Where(t => t.Type == TransactionType.Expense)
            .Sum(t => t.Value);

        return ServiceResult<AccountSummaryResponse>.Ok(
            new AccountSummaryResponse(totalIncome, totalExpense, totalIncome - totalExpense, from, to));
    }

    public async Task<ServiceResult<List<CategorySpendingResponse>>> GetByCategoryAsync(
        Guid accountId, Guid userId, DateTimeOffset? from, DateTimeOffset? to)
    {
        var account = await context.Accounts
            .FirstOrDefaultAsync(a => a.Id == accountId && a.UserId == userId);

        if (account is null) return ServiceResult<List<CategorySpendingResponse>>.NotFound();

        var transactions = await context.Transactions
            .Where(t => t.AccountId == accountId && t.Type == TransactionType.Expense)
            .Where(t => !from.HasValue || t.OccurredAt >= from.Value)
            .Where(t => !to.HasValue || t.OccurredAt <= to.Value)
            .Include(t => t.TransactionCategories)
                .ThenInclude(tc => tc.Category)
            .ToListAsync();

        var categorized = transactions
            .Where(t => t.TransactionCategories.Any())
            .SelectMany(t => t.TransactionCategories
                .Select(tc => new { tc.Category, Transaction = t }))
            .GroupBy(x => x.Category.Id)
            .Select(g => new CategorySpendingResponse(
                g.Key,
                g.First().Category.Name,
                g.First().Category.Color,
                g.First().Category.Emoji,
                g.Sum(x => x.Transaction.Value),
                g.Select(x => x.Transaction.Id).Distinct().Count()))
            .ToList();

        var uncategorized = transactions
            .Where(t => !t.TransactionCategories.Any())
            .ToList();

        if (uncategorized.Count > 0)
        {
            categorized.Add(new CategorySpendingResponse(
                null, "Uncategorized", null, null,
                uncategorized.Sum(t => t.Value),
                uncategorized.Count));
        }

        return ServiceResult<List<CategorySpendingResponse>>.Ok(categorized);
    }
}
