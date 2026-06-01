using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
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

            if (url.Contains("check.eva.ua"))
                return ParseEvaReceipt(html, url);

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

    private static ParsedReceipt ParseEvaReceipt(string rawHtml, string url)
    {
        // The page renders receipt data via JS. The actual content is in a
        // dataArray variable embedded in the script, not in rendered HTML.
        var arrayMatch = Regex.Match(rawHtml, @"const dataArray = (\[\[.*?\]\]);", RegexOptions.Singleline);
        if (!arrayMatch.Success)
            return new ParsedReceipt("Магазин EVA", DateTimeOffset.UtcNow, 0, "UAH", []);

        List<List<string>>? dataArray;
        try { dataArray = JsonSerializer.Deserialize<List<List<string>>>(arrayMatch.Groups[1].Value); }
        catch { return new ParsedReceipt("Магазин EVA", DateTimeOffset.UtcNow, 0, "UAH", []); }

        if (dataArray is null || dataArray.Count == 0 || dataArray[0].Count == 0)
            return new ParsedReceipt("Магазин EVA", DateTimeOffset.UtcNow, 0, "UAH", []);

        var lines = dataArray[0]
            .Select(l => l.Trim())
            .Where(l => l.Length > 0 && !l.All(c => c == '-'))
            .ToList();

        // Extract date: "24-09-2025              14:45:49"
        var occurredAt = DateTimeOffset.UtcNow;
        var dtRegex = new Regex(@"(\d{2}-\d{2}-\d{4})\s+(\d{2}:\d{2}:\d{2})");
        foreach (var line in lines)
        {
            var dm = dtRegex.Match(line);
            if (!dm.Success) continue;
            if (DateTimeOffset.TryParseExact(
                    $"{dm.Groups[1].Value} {dm.Groups[2].Value}",
                    "dd-MM-yyyy HH:mm:ss",
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal,
                    out var parsed))
                occurredAt = parsed;
            break;
        }

        // Item parsing:
        // "N  x  PRICE"  → starts an item block
        // following lines → name parts
        // "NAME_END   PRICE А" (2+ spaces before price, VAT letter at end) → closes block
        var mulRegex = new Regex(@"^\s*([\d,\.]+)\s*[xX]\s*([\d,\.]+)\s*$");
        // The final item line: optional name text, 2+ spaces, price, space, uppercase cyrillic/latin letter
        var totalLineRegex = new Regex(@"^(.*?)\s{2,}(\d[\d,\.]*)\s+[А-ЯҐЄІЇA-Z]\s*$");

        var items = new List<ParsedReceiptItem>();
        decimal pendingQty = 1;
        decimal pendingUnitPrice = 0;
        var pendingNameParts = new List<string>();
        var inItem = false;

        var skipPrefixes = new[] { "ШК:", "#", "Касир", "Сума", "СУМА", "РАЗОМ", "ЧЕК", "ФІСКАЛЬНИЙ",
            "БЕЗГОТІВКОВА", "ГАМАНЕЦЬ", "ПДВ", "ТЕРМІНАЛ", "КОМІСІЯ", "ВИД ", "ЕПЗ", "КОД АВТ",
            "RRN", "ІНШЕ", "ІДЕНТ", "ПЛАТІЖНА", "ДОБРОГО", "НА ВАШИХ", "EVAріанти", "ФН ПРРО",
            "PosService", "ТОВ", "ПН " };
        var skipExact = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "грн", "Онлайн", "Офлайн" };

        foreach (var line in lines)
        {
            if (skipExact.Contains(line) ||
                skipPrefixes.Any(p => line.StartsWith(p, StringComparison.OrdinalIgnoreCase)))
            {
                if (!line.StartsWith("#", StringComparison.Ordinal))
                {
                    inItem = false;
                    pendingNameParts.Clear();
                }
                continue;
            }

            var mulMatch = mulRegex.Match(line);
            if (mulMatch.Success)
            {
                inItem = true;
                pendingQty = ParseAmount(mulMatch.Groups[1].Value);
                pendingUnitPrice = ParseAmount(mulMatch.Groups[2].Value);
                pendingNameParts.Clear();
                continue;
            }

            if (!inItem) continue;

            var totalMatch = totalLineRegex.Match(line);
            if (totalMatch.Success)
            {
                var lastPart = totalMatch.Groups[1].Value.Trim();
                var total = ParseAmount(totalMatch.Groups[2].Value);

                if (total > 0)
                {
                    pendingNameParts.Add(lastPart);
                    var fullName = Regex.Replace(
                        string.Join(" ", pendingNameParts.Where(p => !string.IsNullOrWhiteSpace(p))),
                        @"\s+", " ").Trim();
                    var qty = pendingQty > 0 ? pendingQty : 1;
                    var unitPrice = pendingUnitPrice > 0 ? pendingUnitPrice : total / qty;
                    items.Add(new ParsedReceiptItem(fullName, qty, null, unitPrice, total));
                }

                inItem = false;
                pendingNameParts.Clear();
                continue;
            }

            pendingNameParts.Add(line);
        }

        // Extract receipt total from "СУМА   486.63 ГРН"
        var totalRx = new Regex(@"СУМА\s+([\d,\.]+)\s+ГРН", RegexOptions.IgnoreCase);
        decimal receiptTotal = 0;
        foreach (var line in lines)
        {
            var tm = totalRx.Match(line);
            if (!tm.Success) continue;
            receiptTotal = ParseAmount(tm.Groups[1].Value);
            break;
        }
        if (receiptTotal <= 0) receiptTotal = items.Sum(i => i.TotalPrice);

        return new ParsedReceipt("Магазин EVA", occurredAt, receiptTotal, "UAH", items);
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
