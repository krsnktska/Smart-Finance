using System.Globalization;
using System.Text.RegularExpressions;
using SmartFinance.Models;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public partial class ReceiptParserService(ILogger<ReceiptParserService> logger) : IReceiptParserService
{
    // Matches item lines like:  Молоко 2.5% 1л   1  45.99  45.99
    [GeneratedRegex(@"^(.+?)\s+([\d,\.]+)\s*([а-яА-Яa-zA-Z]*)\s*[xX*]\s*([\d,\.]+)\s+([\d,\.]+)\s*$")]
    private static partial Regex ItemLineWithQuantityRegex();

    // Matches simpler lines like:  Хліб пшеничний    28.50
    [GeneratedRegex(@"^(.+?)\s+([\d,\.]+)\s*$")]
    private static partial Regex SimpleItemLineRegex();

    // Matches total line
    [GeneratedRegex(@"(?:СУМА|РАЗОМ|TOTAL|ПІДСУМОК|ДО\s*СПЛАТИ)\s*:?\s*([\d\s,\.]+)", RegexOptions.IgnoreCase)]
    private static partial Regex TotalRegex();

    // Matches date patterns: 25.12.2024 or 25/12/2024 or 2024-12-25
    [GeneratedRegex(@"(\d{2}[.\/-]\d{2}[.\/-]\d{4}|\d{4}[.\/-]\d{2}[.\/-]\d{2})")]
    private static partial Regex DateRegex();

    // Matches time
    [GeneratedRegex(@"\b(\d{2}:\d{2}(?::\d{2})?)\b")]
    private static partial Regex TimeRegex();

    // Known Ukrainian store names
    private static readonly string[] KnownStores = ["Сільпо", "АТБ", "Рост", "Новус", "METRO", "Ашан", "Billa", "Фора", "ЕКО", "Varus"];

    public ParsedReceipt Parse(string ocrText)
    {
        var lines = ocrText
            .Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Select(l => l.Trim())
            .Where(l => l.Length > 0)
            .ToList();

        var storeName = ExtractStoreName(lines);
        var occurredAt = ExtractDateTime(ocrText);
        var total = ExtractTotal(ocrText);
        var currency = DetectCurrency(ocrText);
        var items = ExtractItems(lines, total);

        return new ParsedReceipt(storeName, occurredAt, total, currency, items);
    }

    private static string ExtractStoreName(List<string> lines)
    {
        foreach (var line in lines.Take(5))
        {
            foreach (var store in KnownStores)
            {
                if (line.Contains(store, StringComparison.OrdinalIgnoreCase))
                    return store;
            }
        }
        return lines.FirstOrDefault(l => l.Length > 3 && !l.All(char.IsDigit)) ?? "Магазин";
    }

    private static DateTimeOffset ExtractDateTime(string text)
    {
        var dateMatch = DateRegex().Match(text);
        var timeMatch = TimeRegex().Match(text);

        if (!dateMatch.Success) return DateTimeOffset.UtcNow;

        var datePart = dateMatch.Value.Replace("/", ".").Replace("-", ".");
        var timePart = timeMatch.Success ? timeMatch.Value : "00:00";

        var formats = new[] { "dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm", "yyyy.MM.dd HH:mm:ss", "yyyy.MM.dd HH:mm" };
        if (DateTimeOffset.TryParseExact($"{datePart} {timePart}", formats, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var result))
            return result;

        return DateTimeOffset.UtcNow;
    }

    private static decimal ExtractTotal(string text)
    {
        var match = TotalRegex().Match(text);
        if (!match.Success) return 0;

        var raw = match.Groups[1].Value.Replace(" ", "").Replace(",", ".");
        return decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var total) ? total : 0;
    }

    private static string DetectCurrency(string text)
    {
        if (text.Contains("грн", StringComparison.OrdinalIgnoreCase) || text.Contains("UAH")) return "UAH";
        if (text.Contains("USD") || text.Contains("$")) return "USD";
        if (text.Contains("EUR") || text.Contains("€")) return "EUR";
        return "UAH";
    }

    private List<ParsedReceiptItem> ExtractItems(List<string> lines, decimal receiptTotal)
    {
        var items = new List<ParsedReceiptItem>();
        var skipKeywords = new[] { "СУМА", "РАЗОМ", "TOTAL", "ПДВ", "VAT", "ЗНИЖКА", "CASHBACK", "БОНУС", "ФОП", "ТОВ", "ЧЕК", "ФІСКАЛЬНИЙ" };

        foreach (var line in lines)
        {
            if (skipKeywords.Any(k => line.Contains(k, StringComparison.OrdinalIgnoreCase))) continue;

            var withQty = ItemLineWithQuantityRegex().Match(line);
            if (withQty.Success)
            {
                var name = withQty.Groups[1].Value.Trim();
                var qty = ParseDecimal(withQty.Groups[2].Value);
                var unit = withQty.Groups[3].Value.Trim();
                var unitPrice = ParseDecimal(withQty.Groups[4].Value);
                var total = ParseDecimal(withQty.Groups[5].Value);

                if (total > 0 && name.Length > 1)
                    items.Add(new ParsedReceiptItem(name, qty, string.IsNullOrEmpty(unit) ? null : unit, unitPrice, total));

                continue;
            }

            var simple = SimpleItemLineRegex().Match(line);
            if (simple.Success)
            {
                var name = simple.Groups[1].Value.Trim();
                var price = ParseDecimal(simple.Groups[2].Value);

                if (price > 0 && price < receiptTotal * 1.5m && name.Length > 2 && !name.All(char.IsDigit))
                    items.Add(new ParsedReceiptItem(name, 1, null, price, price));
            }
        }

        if (items.Count == 0 && receiptTotal > 0)
        {
            logger.LogWarning("Could not parse individual items, creating single entry");
            items.Add(new ParsedReceiptItem("Покупка", 1, null, receiptTotal, receiptTotal));
        }

        return items;
    }

    private static decimal ParseDecimal(string value) =>
        decimal.TryParse(value.Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, out var d) ? d : 0;
}
