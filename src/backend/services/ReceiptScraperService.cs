using System.Globalization;
using AngleSharp;
using AngleSharp.Dom;
using SmartFinance.Models;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class ReceiptScraperService(IHttpClientFactory httpClientFactory, ILogger<ReceiptScraperService> logger) : IReceiptScraperService
{
    public async Task<ParsedReceipt?> ScrapeAsync(string url)
    {
        try
        {
            var client = httpClientFactory.CreateClient("Scraper");
            var html = await client.GetStringAsync(url);

            var config = Configuration.Default;
            var context = BrowsingContext.New(config);
            var document = await context.OpenAsync(req => req.Content(html));

            if (url.Contains("checkbox.ua") || url.Contains("vchasno.ua"))
                return ParseCheckboxReceipt(document, url);

            if (url.Contains("rozetka.ua"))
                return ParseRozetkaReceipt(document, url);

            if (url.Contains("nova.poshta") || url.Contains("novaposhta.ua"))
                return ParseNovaPoshtaReceipt(document, url);

            return ParseGenericReceipt(document, url);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to scrape receipt from {Url}", url);
            return null;
        }
    }

    private static ParsedReceipt ParseCheckboxReceipt(IDocument doc, string url)
    {
        var storeName = doc.QuerySelector(".receipt-header__title, .seller-name, h1")?.TextContent?.Trim() ?? "Магазин";
        var dateText = doc.QuerySelector(".receipt-header__date, .date")?.TextContent?.Trim();
        var occurredAt = ParseDate(dateText);
        var currency = "UAH";
        var items = new List<ParsedReceiptItem>();

        var rows = doc.QuerySelectorAll(".receipt-goods__item, .goods-item, tr.item");
        foreach (var row in rows)
        {
            var name = row.QuerySelector(".goods-name, .name, td:first-child")?.TextContent?.Trim();
            var qtyText = row.QuerySelector(".goods-count, .qty, td:nth-child(2)")?.TextContent?.Trim();
            var priceText = row.QuerySelector(".goods-price, .price, td:nth-child(3)")?.TextContent?.Trim();
            var totalText = row.QuerySelector(".goods-total, .total, td:last-child")?.TextContent?.Trim();

            if (string.IsNullOrWhiteSpace(name)) continue;

            var qty = ParseAmount(qtyText) is var q && q > 0 ? q : 1;
            var unitPrice = ParseAmount(priceText);
            var total = ParseAmount(totalText);

            if (total <= 0) total = unitPrice * qty;

            items.Add(new ParsedReceiptItem(name, qty, null, unitPrice, total));
        }

        var totalAmountText = doc.QuerySelector(".receipt-total, .total-sum, .amount-total")?.TextContent?.Trim();
        var receiptTotal = ParseAmount(totalAmountText);
        if (receiptTotal <= 0) receiptTotal = items.Sum(i => i.TotalPrice);

        return new ParsedReceipt(storeName, occurredAt, receiptTotal, currency, items);
    }

    private static ParsedReceipt ParseRozetkaReceipt(IDocument doc, string url)
    {
        var storeName = "Rozetka";
        var dateText = doc.QuerySelector(".order-date, [data-testid='order-date']")?.TextContent?.Trim();
        var occurredAt = ParseDate(dateText);
        var items = new List<ParsedReceiptItem>();

        var rows = doc.QuerySelectorAll(".order-item, [data-testid='order-item']");
        foreach (var row in rows)
        {
            var name = row.QuerySelector(".order-item__title, .item-name")?.TextContent?.Trim();
            var priceText = row.QuerySelector(".order-item__price, .item-price")?.TextContent?.Trim();
            var qtyText = row.QuerySelector(".order-item__count, .item-qty")?.TextContent?.Trim();

            if (string.IsNullOrWhiteSpace(name)) continue;

            var qty = ParseAmount(qtyText) is var q && q > 0 ? q : 1;
            var price = ParseAmount(priceText);

            items.Add(new ParsedReceiptItem(name, qty, "шт", price / qty, price));
        }

        var total = items.Sum(i => i.TotalPrice);
        return new ParsedReceipt(storeName, occurredAt, total, "UAH", items);
    }

    private static ParsedReceipt ParseNovaPoshtaReceipt(IDocument doc, string url)
    {
        var storeName = "Нова Пошта";
        var dateText = doc.QuerySelector(".shipment-date, .date-info")?.TextContent?.Trim();
        var occurredAt = ParseDate(dateText);

        var deliveryCostText = doc.QuerySelector(".delivery-cost, .cost-value")?.TextContent?.Trim();
        var cost = ParseAmount(deliveryCostText);

        var items = cost > 0
            ? new List<ParsedReceiptItem> { new("Доставка Нова Пошта", 1, null, cost, cost) }
            : new List<ParsedReceiptItem>();

        return new ParsedReceipt(storeName, occurredAt, cost, "UAH", items);
    }

    private static ParsedReceipt ParseGenericReceipt(IDocument doc, string url)
    {
        var title = doc.Title ?? doc.QuerySelector("h1")?.TextContent?.Trim() ?? new Uri(url).Host;
        var occurredAt = DateTimeOffset.UtcNow;
        var items = new List<ParsedReceiptItem>();

        // Try to find table rows that look like items
        var tables = doc.QuerySelectorAll("table");
        foreach (var table in tables)
        {
            var rows = table.QuerySelectorAll("tr");
            foreach (var row in rows)
            {
                var cells = row.QuerySelectorAll("td").ToList();
                if (cells.Count < 2) continue;

                var name = cells[0].TextContent?.Trim();
                var lastCell = cells.Last().TextContent?.Trim();
                var price = ParseAmount(lastCell);

                if (!string.IsNullOrWhiteSpace(name) && price > 0 && name.Length > 2)
                    items.Add(new ParsedReceiptItem(name, 1, null, price, price));
            }
            if (items.Count > 0) break;
        }

        var total = items.Sum(i => i.TotalPrice);
        return new ParsedReceipt(title, occurredAt, total, "UAH", items);
    }

    private static DateTimeOffset ParseDate(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return DateTimeOffset.UtcNow;

        var formats = new[]
        {
            "dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm", "dd.MM.yyyy",
            "yyyy-MM-ddTHH:mm:ssZ", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"
        };

        foreach (var format in formats)
        {
            if (DateTimeOffset.TryParseExact(text.Trim(), format, null, DateTimeStyles.AssumeUniversal, out var date))
                return date;
        }

        return DateTimeOffset.TryParse(text, out var fallback) ? fallback : DateTimeOffset.UtcNow;
    }

    private static decimal ParseAmount(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return 0;
        var clean = new string(text.Where(c => char.IsDigit(c) || c == '.' || c == ',').ToArray());
        return decimal.TryParse(clean.Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, out var d) ? d : 0;
    }
}
