using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class TransactionService(SmartFinanceDbContext context) : ITransactionService
{
    public async Task<ServiceResult<List<TransactionResponse>>> GetAllAsync(Guid accountId, Guid userId)
    {
        var accountBelongsToUser = await context.Accounts
            .AnyAsync(a => a.Id == accountId && a.UserId == userId);

        if (!accountBelongsToUser) return ServiceResult<List<TransactionResponse>>.Forbidden();

        var transactions = await context.Transactions
            .Where(t => t.AccountId == accountId)
            .Include(t => t.TransactionCategories)
                .ThenInclude(tc => tc.Category)
            .ToListAsync();

        return ServiceResult<List<TransactionResponse>>.Ok(transactions.Select(MapTransaction).ToList());
    }

    public async Task<ServiceResult<TransactionResponse>> GetByIdAsync(Guid id, Guid userId)
    {
        var transaction = await context.Transactions
            .Include(t => t.Account)
            .Include(t => t.TransactionCategories)
                .ThenInclude(tc => tc.Category)
            .FirstOrDefaultAsync(t => t.Id == id && t.Account.UserId == userId);

        if (transaction is null) return ServiceResult<TransactionResponse>.NotFound();

        return ServiceResult<TransactionResponse>.Ok(MapTransaction(transaction));
    }

    public async Task<ServiceResult<TransactionResponse>> CreateAsync(CreateTransactionRequest request, Guid userId)
    {
        var accountBelongsToUser = await context.Accounts
            .AnyAsync(a => a.Id == request.AccountId && a.UserId == userId);

        if (!accountBelongsToUser) return ServiceResult<TransactionResponse>.Forbidden();

        var transaction = new Transaction
        {
            Id = Guid.NewGuid(),
            Type = request.Type,
            SpecialType = request.SpecialType,
            Value = request.Value,
            OccurredAt = request.OccurredAt,
            Name = request.Name,
            Description = request.Description,
            Currency = request.Currency,
            AccountId = request.AccountId
        };

        if (request.CategoryIds is { Count: > 0 })
        {
            transaction.TransactionCategories = request.CategoryIds
                .Select(cid => new TransactionCategory { TransactionId = transaction.Id, CategoryId = cid })
                .ToList();
        }

        context.Transactions.Add(transaction);
        await context.SaveChangesAsync();

        await context.Entry(transaction)
            .Collection(t => t.TransactionCategories)
            .Query()
            .Include(tc => tc.Category)
            .LoadAsync();

        return ServiceResult<TransactionResponse>.Ok(MapTransaction(transaction));
    }

    public async Task<ServiceResult<TransactionResponse>> UpdateAsync(Guid id, Guid userId, UpdateTransactionRequest request)
    {
        var transaction = await context.Transactions
            .Include(t => t.Account)
            .Include(t => t.TransactionCategories)
                .ThenInclude(tc => tc.Category)
            .FirstOrDefaultAsync(t => t.Id == id && t.Account.UserId == userId);

        if (transaction is null) return ServiceResult<TransactionResponse>.NotFound();

        if (request.Type.HasValue) transaction.Type = request.Type.Value;
        if (request.SpecialType.HasValue) transaction.SpecialType = request.SpecialType;
        if (request.Value.HasValue) transaction.Value = request.Value.Value;
        if (request.OccurredAt.HasValue) transaction.OccurredAt = request.OccurredAt.Value;
        if (request.Name is not null) transaction.Name = request.Name;
        if (request.Description is not null) transaction.Description = request.Description;
        if (request.Currency is not null) transaction.Currency = request.Currency;

        if (request.CategoryIds is not null)
        {
            context.RemoveRange(transaction.TransactionCategories);
            transaction.TransactionCategories = request.CategoryIds
                .Select(cid => new TransactionCategory { TransactionId = transaction.Id, CategoryId = cid })
                .ToList();
        }

        await context.SaveChangesAsync();

        return ServiceResult<TransactionResponse>.Ok(MapTransaction(transaction));
    }

    public async Task<ServiceResult> DeleteAsync(Guid id, Guid userId)
    {
        var transaction = await context.Transactions
            .Include(t => t.Account)
            .FirstOrDefaultAsync(t => t.Id == id && t.Account.UserId == userId);

        if (transaction is null) return ServiceResult.NotFound();

        context.Transactions.Remove(transaction);
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }

    private static TransactionResponse MapTransaction(Transaction t) =>
        new(
            t.Id,
            t.Type,
            t.SpecialType,
            t.Value,
            t.OccurredAt,
            t.Name,
            t.Description,
            t.Currency,
            t.AccountId,
            t.TransactionCategories
                .Select(tc => new CategoryResponse(
                    tc.Category.Id,
                    tc.Category.Name,
                    tc.Category.Color,
                    tc.Category.Emoji,
                    tc.Category.UserId))
                .ToList());
}
