using System.Globalization;
using System.Text.RegularExpressions;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text;
using Microsoft.Extensions.Configuration;
using SmartFinance.Models;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public partial class ReceiptParserService(
    IConfiguration configuration,
    IHttpClientFactory httpClientFactory,
    ILogger<ReceiptParserService> logger) : IReceiptParserService
{
    // Matches item lines like:  Молоко 2.5% 1л   1  45.99  45.99
    [GeneratedRegex(@"^(.+?)\s+([\d,\.]+)\s*([а-яА-Яa-zA-Z]*)\s*[xX*]\s*([\d,\.]+)\s+([\d,\.]+)\s*[a-zA-Zа-яА-Я]?\s*$")]
    private static partial Regex ItemLineWithQuantityRegex();

    // Matches simpler lines like:  Хліб пшеничний    28.50
    [GeneratedRegex(@"^(.+?)\s+([\d,\.]+)\s*[a-zA-Zа-яА-Я]?\s*$")]
    private static partial Regex SimpleItemLineRegex();

    // Matches multiplier line (e.g. 1 x 67.50 = )
    [GeneratedRegex(@"^\s*([\d,\.]+)\s*[xX*]\s*([\d,\.]+)\s*=?\s*$")]
    private static partial Regex MultiplierLineRegex();

    // Matches total line with support for homoglyphs
    [GeneratedRegex(@"(?:[СCсc][УУYUyуyu][МMмm][АAаa]|[РPрp][АAаa][ЗZзz][ОOоo][МMмm]|TOTAL|ПІДСУМОК|ДО\s*[СПЛАТИсc]+)\s*:?\s*([\d\s,\.]+)", RegexOptions.IgnoreCase)]
    private static partial Regex TotalRegex();

    // Matches date patterns: 25.12.2024 or 25/12/2024 or 2024-12-25
    [GeneratedRegex(@"(\d{2}[.\/-]\d{2}[.\/-]\d{4}|\d{4}[.\/-]\d{2}[.\/-]\d{2})")]
    private static partial Regex DateRegex();

    // Matches time
    [GeneratedRegex(@"\b(\d{2}:\d{2}(?::\d{2})?)\b")]
    private static partial Regex TimeRegex();

    // Known Ukrainian store names
    private static readonly string[] KnownStores = ["Сільпо", "АТБ", "Рост", "Новус", "METRO", "Ашан", "Billa", "Фора", "ЕКО", "Varus", "Ева", "Eva"];

    public async Task<ParsedReceipt> ParseAsync(string ocrText)
    {
        if (string.IsNullOrWhiteSpace(ocrText))
        {
            return new ParsedReceipt("Магазин", DateTimeOffset.UtcNow, 0, "UAH", new List<ParsedReceiptItem>());
        }

        var apiKey = configuration["AI:ApiKey"] ?? string.Empty;
        if (!string.IsNullOrEmpty(apiKey))
        {
            try
            {
                var aiResult = await ParseWithAiAsync(ocrText, apiKey);
                if (aiResult != null)
                {
                    logger.LogInformation("Successfully parsed receipt using Gemini AI!");
                    return aiResult;
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed parsing receipt with Gemini AI, falling back to regex parser");
            }
        }
        else
        {
            logger.LogWarning("Gemini API key is not configured. Falling back to regex parser");
        }

        return ParseRegexFallback(ocrText);
    }

    private async Task<ParsedReceipt?> ParseWithAiAsync(string ocrText, string apiKey)
    {
        var apiUrl = configuration["AI:ApiUrl"] ?? "https://generativelanguage.googleapis.com/v1beta/models/{0}:generateContent?key={1}";
        var model = configuration["AI:Model"] ?? "gemini-2.5-flash";

        var client = httpClientFactory.CreateClient("AI");

        var systemPrompt = 
            "You are a receipt parser. Analyze the OCR text of a receipt and extract structured receipt data as JSON. " +
            "Return a JSON object conforming exactly to the following structure:\n" +
            "{\n" +
            "  \"storeName\": \"Name of the store\",\n" +
            "  \"occurredAt\": \"ISO 8601 offset format, e.g. 2026-06-04T19:30:00+03:00. Extract correct date and time from receipt. If not specified or incomplete, use the current time.\",\n" +
            "  \"total\": 123.45,\n" +
            "  \"currency\": \"UAH or USD or EUR. Default to UAH.\",\n" +
            "  \"items\": [\n" +
            "    {\n" +
            "      \"name\": \"Item name (e.g. Молоко 2.5%)\",\n" +
            "      \"quantity\": 1.0,\n" +
            "      \"unit\": \"unit of measurement (e.g. шт, кг, л, or null if none)\",\n" +
            "      \"unitPrice\": 45.99,\n" +
            "      \"totalPrice\": 45.99\n" +
            "    }\n" +
            "  ]\n" +
            "}\n" +
            "Make sure to clean up item names from duplicates or OCR noise. " +
            "Verify that item quantity multiplied by unitPrice roughly equals totalPrice. " +
            "Do not include discounts or taxes as separate items; apply discounts to item prices if possible, or adjust total. " +
            "Return only the valid JSON response, without markdown code block formatting.";

        var requestBody = new
        {
            contents = new[]
            {
                new
                {
                    role = "user",
                    parts = new[] { new { text = ocrText } }
                }
            },
            systemInstruction = new
            {
                parts = new[] { new { text = systemPrompt } }
            },
            generationConfig = new
            {
                temperature = 0.1,
                responseMimeType = "application/json"
            }
        };

        var json = JsonSerializer.Serialize(requestBody);
        var url = string.Format(apiUrl, model, apiKey);

        var response = await client.PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json"));
        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            logger.LogWarning("Gemini API returned {Status} when parsing receipt. Body: {Body}", response.StatusCode, errorBody);
            return null;
        }

        var responseJson = await response.Content.ReadAsStringAsync();
        var aiResponse = JsonSerializer.Deserialize<GeminiResponse>(responseJson);
        var content = aiResponse?.Candidates?.FirstOrDefault()?.Content?.Parts?.FirstOrDefault()?.Text;

        if (string.IsNullOrWhiteSpace(content))
        {
            return null;
        }

        var options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        };

        return JsonSerializer.Deserialize<ParsedReceipt>(content, options);
    }

    private ParsedReceipt ParseRegexFallback(string ocrText)
    {
        var trimmed = ocrText.Trim();
        if (trimmed.StartsWith("{") && trimmed.EndsWith("}"))
        {
            try
            {
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var parsed = JsonSerializer.Deserialize<ParsedReceipt>(trimmed, options);
                if (parsed is not null && parsed.Items is not null)
                {
                    logger.LogInformation("Successfully parsed receipt directly from Claude JSON!");
                    return parsed;
                }
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Failed to parse Claude JSON, falling back to regex parser");
            }
        }

        var rawLines = ocrText
            .Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Select(l => l.Trim())
            .Where(l => l.Length > 0)
            .ToList();

        // Remove consecutive duplicate lines to prevent layout-based OCR duplication bugs (with whitespace normalization)
        var lines = new List<string>();
        foreach (var line in rawLines)
        {
            if (lines.Count == 0)
            {
                lines.Add(line);
                continue;
            }

            var prevNormalized = Regex.Replace(lines[^1], @"\s+", " ").Trim();
            var currNormalized = Regex.Replace(line, @"\s+", " ").Trim();

            if (prevNormalized != currNormalized)
            {
                lines.Add(line);
            }
        }

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
        // "буд." filters Ukrainian address lines (e.g. "шосе, буд. 248") where the house number looks like a price
        var skipKeywords = new[] { "СУМА", "РАЗОМ", "TOTAL", "ПДВ", "VAT", "ЗНИЖКА", "CASHBACK", "БОНУС", "ФОП", "ТОВ", "ЧЕК", "ФІСКАЛЬНИЙ", "буд." };

        var inItemBlock = false;
        var hasSeenMultiplier = false;
        var pendingQuantity = 1.0m;
        var pendingUnitPrice = 0.0m;
        var pendingNameLines = new List<string>();

        foreach (var line in lines)
        {
            if (skipKeywords.Any(k => line.Contains(k, StringComparison.OrdinalIgnoreCase)))
            {
                inItemBlock = false;
                pendingNameLines.Clear();
                continue;
            }

            var multiplierMatch = MultiplierLineRegex().Match(line);
            if (multiplierMatch.Success)
            {
                inItemBlock = true;
                hasSeenMultiplier = true;
                pendingQuantity = ParseDecimal(multiplierMatch.Groups[1].Value);
                pendingUnitPrice = ParseDecimal(multiplierMatch.Groups[2].Value);
                pendingNameLines.Clear();
                continue;
            }

            var withQty = ItemLineWithQuantityRegex().Match(line);
            if (withQty.Success)
            {
                var name = withQty.Groups[1].Value.Trim();
                var qty = ParseDecimal(withQty.Groups[2].Value);
                var unit = withQty.Groups[3].Value.Trim();
                var unitPrice = ParseDecimal(withQty.Groups[4].Value);
                var total = ParseDecimal(withQty.Groups[5].Value);

                if (total > 0 && name.Length > 1)
                {
                    if (inItemBlock && pendingNameLines.Count > 0)
                    {
                        name = string.Join(" ", pendingNameLines.Concat(new[] { name }));
                    }
                    items.Add(new ParsedReceiptItem(name, qty, string.IsNullOrEmpty(unit) ? null : unit, unitPrice, total));
                }

                inItemBlock = false;
                pendingNameLines.Clear();
                continue;
            }

            var simple = SimpleItemLineRegex().Match(line);
            if (simple.Success)
            {
                var name = simple.Groups[1].Value.Trim();
                var price = ParseDecimal(simple.Groups[2].Value);

                if (price > 0 && (receiptTotal == 0 || price < receiptTotal * 1.5m) && name.Length > 2 && !name.All(char.IsDigit))
                {
                    // When inside a multiplier block and the matched price is far below the unit price,
                    // this line is a continuation of a split product name (e.g. "200 мл" split as "20" + "0 мл")
                    if (inItemBlock && pendingUnitPrice > 0 && price < pendingUnitPrice * pendingQuantity * 0.5m)
                    {
                        pendingNameLines.Add(line);
                        if (pendingNameLines.Count > 8)
                        {
                            inItemBlock = false;
                            pendingNameLines.Clear();
                        }
                        continue;
                    }

                    // After a multiplier-based receipt is detected, lines outside an item block are
                    // header/footer noise (addresses, totals) — not products
                    if (!inItemBlock && hasSeenMultiplier)
                    {
                        continue;
                    }

                    var qty = inItemBlock ? pendingQuantity : 1.0m;
                    var unitPrice = inItemBlock ? pendingUnitPrice : price;

                    if (inItemBlock && pendingNameLines.Count > 0)
                    {
                        name = string.Join(" ", pendingNameLines.Concat(new[] { name }));
                    }

                    items.Add(new ParsedReceiptItem(name, qty, null, unitPrice, price));
                }

                inItemBlock = false;
                pendingNameLines.Clear();
                continue;
            }

            if (inItemBlock)
            {
                pendingNameLines.Add(line);
                if (pendingNameLines.Count > 4)
                {
                    inItemBlock = false;
                    pendingNameLines.Clear();
                }
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

    private record GeminiResponse([property: JsonPropertyName("candidates")] List<GeminiCandidate>? Candidates);
    private record GeminiCandidate([property: JsonPropertyName("content")] GeminiContent? Content);
    private record GeminiContent([property: JsonPropertyName("parts")] List<GeminiPart>? Parts);
    private record GeminiPart([property: JsonPropertyName("text")] string? Text);
}
