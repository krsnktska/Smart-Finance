using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class ReceiptService(
    SmartFinanceDbContext context,
    IOcrService ocrService,
    IReceiptParserService parserService,
    IAiCategorizationService aiService,
    IReceiptScraperService scraperService,
    ICategoryService categoryService,
    ILogger<ReceiptService> logger) : IReceiptService
{
    public async Task<ServiceResult<ReceiptScanResponse>> ScanPhotoAsync(IFormFile image, Guid accountId, Guid userId)
    {
        var accountBelongsToUser = await context.Accounts.AnyAsync(a => a.Id == accountId && a.UserId == userId);
        if (!accountBelongsToUser) return ServiceResult<ReceiptScanResponse>.Forbidden();

        if (image.Length == 0)
            return ServiceResult<ReceiptScanResponse>.BadRequest();

        try
        {
            await using var stream = image.OpenReadStream();
            var text = await ocrService.ExtractTextAsync(stream);
            logger.LogInformation("OCR extracted text ({Chars} chars) for account {AccountId}", text.Length, accountId);

            var parsed = parserService.Parse(text);
            return await CreateResponseFromParsed(parsed, accountId, userId, "Сканування фото чека");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Receipt photo scan failed");
            return ServiceResult<ReceiptScanResponse>.BadRequest();
        }
    }

    public async Task<ServiceResult<ReceiptScanResponse>> ScrapeUrlAsync(ScrapeReceiptRequest request, Guid userId)
    {
        var accountBelongsToUser = await context.Accounts.AnyAsync(a => a.Id == request.AccountId && a.UserId == userId);
        if (!accountBelongsToUser) return ServiceResult<ReceiptScanResponse>.Forbidden();

        var parsed = await scraperService.ScrapeAsync(request.Url);
        if (parsed is null)
            return ServiceResult<ReceiptScanResponse>.BadRequest();

        return await CreateResponseFromParsed(parsed, request.AccountId, userId, $"Скрапінг: {request.Url}");
    }

    private async Task<ServiceResult<ReceiptScanResponse>> CreateResponseFromParsed(
        ParsedReceipt parsed, Guid accountId, Guid userId, string source)
    {
        var categories = await categoryService.GetAllAsync(userId);

        var categoryIds = await aiService.CategorizeItemsAsync(parsed.Items, categories);

        var transaction = new Transaction
        {
            Id = Guid.NewGuid(),
            Type = TransactionType.Expense,
            Value = parsed.Total > 0 ? parsed.Total : parsed.Items.Sum(i => i.TotalPrice),
            OccurredAt = parsed.OccurredAt,
            Name = parsed.StoreName,
            Description = $"{source}. Товарів: {parsed.Items.Count}",
            Currency = parsed.Currency,
            AccountId = accountId,
            TransactionCategories = categoryIds
                .Where(id => id != Guid.Empty)
                .Distinct()
                .Select(id => new TransactionCategory { CategoryId = id })
                .ToList()
        };

        transaction.ReceiptItems = parsed.Items.Select(item => new ReceiptItem
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

        return ServiceResult<ReceiptScanResponse>.Ok(new ReceiptScanResponse(transactionResponse, itemResponses));
    }

    private static TransactionResponse MapTransaction(Transaction t) =>
        new(t.Id, t.Type, t.SpecialType, t.Value, t.OccurredAt, t.Name, t.Description, t.Currency, t.AccountId,
            t.TransactionCategories.Select(tc => new CategoryResponse(tc.Category.Id, tc.Category.Name, tc.Category.Color, tc.Category.Emoji, tc.Category.UserId)).ToList());

    private static ReceiptItemResponse MapItem(ReceiptItem i) =>
        new(i.Id, i.Name, i.Quantity, i.Unit, i.UnitPrice, i.TotalPrice);
}
