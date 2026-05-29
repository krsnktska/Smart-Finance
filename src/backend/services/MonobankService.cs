using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class MonobankService(
    SmartFinanceDbContext context,
    IHttpClientFactory httpClientFactory,
    ILogger<MonobankService> logger) : IMonobankService
{
    private const string MonoBaseUrl = "https://api.monobank.ua";

    public async Task<ServiceResult<BankIntegrationResponse>> SetupAsync(SetupBankIntegrationRequest request, Guid userId)
    {
        var accountBelongsToUser = await context.Accounts.AnyAsync(a => a.Id == request.AccountId && a.UserId == userId);
        if (!accountBelongsToUser) return ServiceResult<BankIntegrationResponse>.Forbidden();

        var client = CreateClient(request.ApiToken);

        try
        {
            // Verify token by fetching client info
            var clientInfoResponse = await client.GetAsync($"{MonoBaseUrl}/personal/client-info");
            if (!clientInfoResponse.IsSuccessStatusCode)
                return ServiceResult<BankIntegrationResponse>.BadRequest();

            var clientInfoJson = await clientInfoResponse.Content.ReadAsStringAsync();
            var clientInfo = JsonSerializer.Deserialize<MonoClientInfo>(clientInfoJson);

            var bankAccountId = request.BankAccountId ?? clientInfo?.Accounts?.FirstOrDefault()?.Id;

            var existing = await context.BankIntegrations
                .FirstOrDefaultAsync(b => b.UserId == userId && b.BankType == BankType.Monobank && b.BankAccountId == bankAccountId);

            if (existing is not null)
            {
                existing.ApiToken = request.ApiToken;
                existing.AccountId = request.AccountId;
            }
            else
            {
                existing = new BankIntegration
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    BankType = BankType.Monobank,
                    ApiToken = request.ApiToken,
                    AccountId = request.AccountId,
                    BankAccountId = bankAccountId
                };
                context.BankIntegrations.Add(existing);
            }

            await context.SaveChangesAsync();
            return ServiceResult<BankIntegrationResponse>.Ok(MapIntegration(existing));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Monobank setup failed");
            return ServiceResult<BankIntegrationResponse>.BadRequest();
        }
    }

    public async Task<ServiceResult<List<TransactionResponse>>> SyncAsync(SyncBankRequest request, Guid userId)
    {
        var integration = await context.BankIntegrations
            .FirstOrDefaultAsync(b => b.Id == request.IntegrationId && b.UserId == userId && b.BankType == BankType.Monobank);

        if (integration is null) return ServiceResult<List<TransactionResponse>>.NotFound();

        var client = CreateClient(integration.ApiToken);
        var from = request.From.ToUnixTimeSeconds();
        var to = request.To.ToUnixTimeSeconds();
        var accountId = integration.BankAccountId ?? "0";

        try
        {
            var response = await client.GetAsync($"{MonoBaseUrl}/personal/statement/{accountId}/{from}/{to}");
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Monobank statement fetch failed: {Status}", response.StatusCode);
                return ServiceResult<List<TransactionResponse>>.BadRequest();
            }

            var json = await response.Content.ReadAsStringAsync();
            var transactions = JsonSerializer.Deserialize<List<MonoTransaction>>(json) ?? [];

            var created = new List<TransactionResponse>();

            foreach (var mono in transactions)
            {
                // Skip if already imported (check by external reference)
                var alreadyExists = await context.Transactions
                    .AnyAsync(t => t.AccountId == integration.AccountId && t.Description != null && t.Description.Contains(mono.Id));

                if (alreadyExists) continue;

                var amountUah = Math.Abs(mono.Amount) / 100m;
                var type = mono.Amount < 0 ? TransactionType.Expense : TransactionType.Income;

                var transaction = new Transaction
                {
                    Id = Guid.NewGuid(),
                    Type = type,
                    Value = amountUah,
                    OccurredAt = DateTimeOffset.FromUnixTimeSeconds(mono.Time),
                    Name = mono.Description ?? "Monobank транзакція",
                    Description = $"Monobank ID: {mono.Id}. MCC: {mono.Mcc}",
                    Currency = ResolveCurrency(mono.CurrencyCode),
                    AccountId = integration.AccountId
                };

                context.Transactions.Add(transaction);
                created.Add(MapTransaction(transaction));
            }

            if (created.Count > 0)
            {
                integration.LastSyncedAt = DateTimeOffset.UtcNow;
                await context.SaveChangesAsync();
            }

            return ServiceResult<List<TransactionResponse>>.Ok(created);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Monobank sync failed");
            return ServiceResult<List<TransactionResponse>>.BadRequest();
        }
    }

    public async Task<ServiceResult<List<BankIntegrationResponse>>> GetIntegrationsAsync(Guid userId)
    {
        var integrations = await context.BankIntegrations
            .Where(b => b.UserId == userId && b.BankType == BankType.Monobank)
            .ToListAsync();

        return ServiceResult<List<BankIntegrationResponse>>.Ok(integrations.Select(MapIntegration).ToList());
    }

    private HttpClient CreateClient(string token)
    {
        var client = httpClientFactory.CreateClient("Monobank");
        client.DefaultRequestHeaders.Add("X-Token", token);
        return client;
    }

    private static string ResolveCurrency(int code) => code switch
    {
        980 => "UAH",
        840 => "USD",
        978 => "EUR",
        826 => "GBP",
        _ => "UAH"
    };

    private static BankIntegrationResponse MapIntegration(BankIntegration b) =>
        new(b.Id, b.BankType.ToString(), b.AccountId, b.BankAccountId, b.LastSyncedAt);

    private static TransactionResponse MapTransaction(Transaction t) =>
        new(t.Id, t.Type, t.SpecialType, t.Value, t.OccurredAt, t.Name, t.Description, t.Currency, t.AccountId, []);

    private record MonoClientInfo(
        [property: JsonPropertyName("name")] string? Name,
        [property: JsonPropertyName("accounts")] List<MonoAccount>? Accounts);

    private record MonoAccount(
        [property: JsonPropertyName("id")] string Id,
        [property: JsonPropertyName("currencyCode")] int CurrencyCode,
        [property: JsonPropertyName("balance")] long Balance);

    private record MonoTransaction(
        [property: JsonPropertyName("id")] string Id,
        [property: JsonPropertyName("time")] long Time,
        [property: JsonPropertyName("description")] string? Description,
        [property: JsonPropertyName("mcc")] int Mcc,
        [property: JsonPropertyName("amount")] long Amount,
        [property: JsonPropertyName("operationAmount")] long OperationAmount,
        [property: JsonPropertyName("currencyCode")] int CurrencyCode,
        [property: JsonPropertyName("balance")] long Balance,
        [property: JsonPropertyName("comment")] string? Comment);
}
