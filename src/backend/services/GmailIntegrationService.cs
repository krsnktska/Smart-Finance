using System.Text;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Auth.OAuth2.Flows;
using Google.Apis.Gmail.v1;
using Google.Apis.Gmail.v1.Data;
using Google.Apis.Services;
using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class GmailIntegrationService(
    SmartFinanceDbContext context,
    IConfiguration configuration,
    IReceiptScraperService scraperService,
    IReceiptParserService parserService,
    IAiCategorizationService aiService,
    ICategoryService categoryService,
    ILogger<GmailIntegrationService> logger) : IGmailIntegrationService
{
    private readonly string _clientId = configuration["Gmail:ClientId"] ?? string.Empty;
    private readonly string _clientSecret = configuration["Gmail:ClientSecret"] ?? string.Empty;
    private readonly string _redirectUri = configuration["Gmail:RedirectUri"] ?? "http://localhost:5050/api/gmail/callback";

    private readonly string[] _scopes = [GmailService.Scope.GmailReadonly];

    private static readonly string[] ReceiptSenders =
    [
        "noreply@checkbox.ua", "receipt@privatbank.ua", "info@monobank.ua",
        "rozetka@rozetka.com.ua", "noreply@nova.poshta", "orders@silpo.ua",
        "receipts@ukrposhta.ua"
    ];

    private static readonly string[] ReceiptSubjectKeywords =
        ["чек", "квитанція", "receipt", "замовлення", "покупка", "оплата"];

    public string GetAuthorizationUrl(Guid userId)
    {
        var flow = CreateFlow();
        return flow.CreateAuthorizationCodeRequest(_redirectUri).Build().AbsoluteUri
               + $"&state={userId}";
    }

    public async Task<ServiceResult<GmailIntegrationResponse>> HandleCallbackAsync(string code, Guid userId, Guid accountId)
    {
        try
        {
            var flow = CreateFlow();
            var token = await flow.ExchangeCodeForTokenAsync(userId.ToString(), code, _redirectUri, CancellationToken.None);

            var credential = new UserCredential(flow, userId.ToString(), token);
            var gmailService = new GmailService(new BaseClientService.Initializer
            {
                HttpClientInitializer = credential,
                ApplicationName = "SmartFinance"
            });

            var profile = await gmailService.Users.GetProfile("me").ExecuteAsync();
            var email = profile.EmailAddress;

            var existing = await context.GmailTokens.FirstOrDefaultAsync(t => t.UserId == userId);
            if (existing is not null)
            {
                existing.AccessToken = token.AccessToken;
                existing.RefreshToken = token.RefreshToken ?? existing.RefreshToken;
                existing.TokenExpiry = DateTimeOffset.UtcNow.AddSeconds(token.ExpiresInSeconds ?? 3600);
                existing.GmailAddress = email;
            }
            else
            {
                context.GmailTokens.Add(new GmailToken
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    AccessToken = token.AccessToken,
                    RefreshToken = token.RefreshToken,
                    TokenExpiry = DateTimeOffset.UtcNow.AddSeconds(token.ExpiresInSeconds ?? 3600),
                    GmailAddress = email
                });
            }

            await context.SaveChangesAsync();
            return ServiceResult<GmailIntegrationResponse>.Ok(new GmailIntegrationResponse(email, null));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Gmail OAuth callback failed");
            return ServiceResult<GmailIntegrationResponse>.BadRequest();
        }
    }

    public async Task<ServiceResult<List<ReceiptScanResponse>>> ScanInboxAsync(Guid userId, Guid accountId)
    {
        var tokenRecord = await context.GmailTokens.FirstOrDefaultAsync(t => t.UserId == userId);
        if (tokenRecord is null) return ServiceResult<List<ReceiptScanResponse>>.NotFound();

        var accountBelongsToUser = await context.Accounts.AnyAsync(a => a.Id == accountId && a.UserId == userId);
        if (!accountBelongsToUser) return ServiceResult<List<ReceiptScanResponse>>.Forbidden();

        try
        {
            var flow = CreateFlow();
            var token = new Google.Apis.Auth.OAuth2.Responses.TokenResponse
            {
                AccessToken = tokenRecord.AccessToken,
                RefreshToken = tokenRecord.RefreshToken,
                ExpiresInSeconds = (long)(tokenRecord.TokenExpiry - DateTimeOffset.UtcNow).TotalSeconds
            };

            var credential = new UserCredential(flow, userId.ToString(), token);
            var gmailService = new GmailService(new BaseClientService.Initializer
            {
                HttpClientInitializer = credential,
                ApplicationName = "SmartFinance"
            });

            var query = BuildReceiptQuery(tokenRecord.LastScannedAt);
            var request = gmailService.Users.Messages.List("me");
            request.Q = query;
            request.MaxResults = 50;

            var response = await request.ExecuteAsync();
            var results = new List<ReceiptScanResponse>();

            if (response.Messages is null)
                return ServiceResult<List<ReceiptScanResponse>>.Ok(results);

            var categories = await categoryService.GetAllAsync(userId);

            foreach (var msgRef in response.Messages)
            {
                var msg = await gmailService.Users.Messages.Get("me", msgRef.Id).ExecuteAsync();
                var receiptUrls = ExtractReceiptUrls(msg);

                foreach (var url in receiptUrls)
                {
                    var scraped = await scraperService.ScrapeAsync(url);
                    if (scraped is null) continue;

                    var categoryIds = await aiService.CategorizeItemsAsync(scraped.Items, categories);
                    var transaction = await CreateTransactionFromReceipt(scraped, accountId, userId, categoryIds);

                    if (transaction is not null)
                        results.Add(transaction);
                }

                // Also parse inline text receipts from email body
                var body = GetEmailBody(msg);
                if (!string.IsNullOrEmpty(body) && receiptUrls.Count == 0)
                {
                    var parsed = parserService.Parse(body);
                    if (parsed.Total > 0)
                    {
                        var categoryIds = await aiService.CategorizeItemsAsync(parsed.Items, categories);
                        var transaction = await CreateTransactionFromReceipt(parsed, accountId, userId, categoryIds);
                        if (transaction is not null) results.Add(transaction);
                    }
                }
            }

            tokenRecord.LastScannedAt = DateTimeOffset.UtcNow;
            await context.SaveChangesAsync();

            return ServiceResult<List<ReceiptScanResponse>>.Ok(results);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Gmail inbox scan failed for user {UserId}", userId);
            return ServiceResult<List<ReceiptScanResponse>>.BadRequest();
        }
    }

    public async Task<GmailIntegrationResponse?> GetStatusAsync(Guid userId)
    {
        var token = await context.GmailTokens.FirstOrDefaultAsync(t => t.UserId == userId);
        if (token is null) return null;
        return new GmailIntegrationResponse(token.GmailAddress, token.LastScannedAt);
    }

    private GoogleAuthorizationCodeFlow CreateFlow() => new(new GoogleAuthorizationCodeFlow.Initializer
    {
        ClientSecrets = new ClientSecrets { ClientId = _clientId, ClientSecret = _clientSecret },
        Scopes = _scopes
    });

    private static string BuildReceiptQuery(DateTimeOffset? since)
    {
        var senderFilter = string.Join(" OR ", ReceiptSenders.Select(s => $"from:{s}"));
        var subjectFilter = string.Join(" OR ", ReceiptSubjectKeywords.Select(k => $"subject:{k}"));
        var dateFilter = since.HasValue ? $" after:{since.Value.ToUnixTimeSeconds()}" : "";
        return $"({senderFilter}) OR ({subjectFilter}){dateFilter}";
    }

    private static List<string> ExtractReceiptUrls(Message msg)
    {
        var urls = new List<string>();
        var body = GetEmailBody(msg);
        if (string.IsNullOrEmpty(body)) return urls;

        var urlPattern = new System.Text.RegularExpressions.Regex(
            @"https?://(?:checkbox\.ua|vchasno\.ua|receipts\.[a-z]+\.ua|check\.[a-z]+\.ua)[^\s""'<>]+",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        foreach (System.Text.RegularExpressions.Match match in urlPattern.Matches(body))
            urls.Add(match.Value);

        return urls.Distinct().ToList();
    }

    private static string GetEmailBody(Message msg)
    {
        try
        {
            var payload = msg.Payload;
            if (payload?.Body?.Data is not null)
                return Encoding.UTF8.GetString(Convert.FromBase64String(payload.Body.Data.Replace('-', '+').Replace('_', '/')));

            var textPart = payload?.Parts?.FirstOrDefault(p => p.MimeType == "text/plain" || p.MimeType == "text/html");
            if (textPart?.Body?.Data is not null)
                return Encoding.UTF8.GetString(Convert.FromBase64String(textPart.Body.Data.Replace('-', '+').Replace('_', '/')));
        }
        catch { /* ignore decode errors */ }
        return string.Empty;
    }

    private async Task<ReceiptScanResponse?> CreateTransactionFromReceipt(
        ParsedReceipt receipt, Guid accountId, Guid userId, List<Guid> categoryIds)
    {
        if (receipt.Total <= 0) return null;

        var primaryCategoryId = categoryIds.FirstOrDefault(id => id != Guid.Empty);
        var transaction = new Transaction
        {
            Id = Guid.NewGuid(),
            Type = TransactionType.Expense,
            Value = receipt.Total,
            OccurredAt = receipt.OccurredAt,
            Name = receipt.StoreName,
            Description = $"Автоматично імпортовано з Gmail. Товарів: {receipt.Items.Count}",
            Currency = receipt.Currency,
            AccountId = accountId,
            TransactionCategories = categoryIds
                .Where(id => id != Guid.Empty)
                .Distinct()
                .Select(id => new TransactionCategory { CategoryId = id })
                .ToList()
        };

        transaction.ReceiptItems = receipt.Items.Select(item => new ReceiptItem
        {
            Id = Guid.NewGuid(),
            TransactionId = transaction.Id,
            Name = item.Name,
            Quantity = item.Quantity,
            Unit = item.Unit,
            UnitPrice = item.UnitPrice,
            TotalPrice = item.TotalPrice
        }).ToList();

        foreach (var tc in transaction.TransactionCategories)
            tc.TransactionId = transaction.Id;

        context.Transactions.Add(transaction);
        await context.SaveChangesAsync();

        await context.Entry(transaction).Collection(t => t.TransactionCategories).Query().Include(tc => tc.Category).LoadAsync();

        var transactionResponse = MapTransaction(transaction);
        var itemResponses = transaction.ReceiptItems.Select(MapItem).ToList();
        return new ReceiptScanResponse(transactionResponse, itemResponses);
    }

    private static TransactionResponse MapTransaction(Transaction t) =>
        new(t.Id, t.Type, t.SpecialType, t.Value, t.OccurredAt, t.Name, t.Description, t.Currency, t.AccountId,
            t.TransactionCategories.Select(tc => new CategoryResponse(tc.Category.Id, tc.Category.Name, tc.Category.Color, tc.Category.Emoji, tc.Category.UserId)).ToList());

    private static ReceiptItemResponse MapItem(ReceiptItem i) =>
        new(i.Id, i.Name, i.Quantity, i.Unit, i.UnitPrice, i.TotalPrice);
}
