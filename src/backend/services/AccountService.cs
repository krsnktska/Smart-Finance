using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class AccountService(SmartFinanceDbContext context) : IAccountService
{
    public async Task<List<AccountResponse>> GetAllAsync(Guid userId) =>
        await context.Accounts
            .Where(a => a.UserId == userId)
            .Select(a => new AccountResponse(a.Id, a.Name, a.Currency, a.UserId))
            .ToListAsync();

    public async Task<ServiceResult<AccountResponse>> GetByIdAsync(Guid id, Guid userId)
    {
        var account = await context.Accounts
            .FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);

        if (account is null) return ServiceResult<AccountResponse>.NotFound();

        return ServiceResult<AccountResponse>.Ok(
            new AccountResponse(account.Id, account.Name, account.Currency, account.UserId));
    }

    public async Task<AccountResponse> CreateAsync(Guid userId, CreateAccountRequest request)
    {
        var account = new Account
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            Currency = request.Currency,
            UserId = userId
        };

        context.Accounts.Add(account);
        await context.SaveChangesAsync();

        return new AccountResponse(account.Id, account.Name, account.Currency, account.UserId);
    }

    public async Task<ServiceResult<AccountResponse>> UpdateAsync(Guid id, Guid userId, UpdateAccountRequest request)
    {
        var account = await context.Accounts
            .FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);

        if (account is null) return ServiceResult<AccountResponse>.NotFound();

        if (request.Name is not null) account.Name = request.Name;
        if (request.Currency is not null) account.Currency = request.Currency;

        await context.SaveChangesAsync();

        return ServiceResult<AccountResponse>.Ok(
            new AccountResponse(account.Id, account.Name, account.Currency, account.UserId));
    }

    public async Task<ServiceResult> DeleteAsync(Guid id, Guid userId)
    {
        var account = await context.Accounts
            .FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);

        if (account is null) return ServiceResult.NotFound();

        context.Accounts.Remove(account);
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }
}
