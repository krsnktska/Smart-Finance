using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using SmartFinance.Models;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class AiCategorizationService(IConfiguration configuration, IHttpClientFactory httpClientFactory, ILogger<AiCategorizationService> logger) : IAiCategorizationService
{
    private readonly string _apiKey = configuration["AI:ApiKey"] ?? string.Empty;
    private readonly string _apiUrl = configuration["AI__ApiUrl"] ?? "https://api.openai.com/v1/chat/completions";
    private readonly string _model = configuration["AI__Model"] ?? "gpt-4o-mini";

    public async Task<List<Guid>> CategorizeItemsAsync(List<ParsedReceiptItem> items, List<CategoryResponse> availableCategories)
    {
        if (string.IsNullOrEmpty(_apiKey) || availableCategories.Count == 0)
            return Enumerable.Repeat(Guid.Empty, items.Count).ToList();

        var categoriesJson = string.Join(", ", availableCategories.Select(c => $"{c.Id}:{c.Name}"));
        var itemsJson = string.Join("\n", items.Select((item, i) => $"{i}: {item.Name}"));

        var systemPrompt = "You are a financial assistant that categorizes grocery and retail items. " +
                           "Return only a JSON array of category IDs corresponding to each item in order. " +
                           "If no category fits, use null.";

        var userPrompt = $"Categories (id:name): {categoriesJson}\n\nItems to categorize (index: name):\n{itemsJson}\n\n" +
                         $"Return a JSON array with {items.Count} elements, each being a category id (UUID) or null.";

        try
        {
            var client = httpClientFactory.CreateClient("AI");
            client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _apiKey);

            var requestBody = new
            {
                model = _model,
                messages = new[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userPrompt }
                },
                temperature = 0,
                max_tokens = 500
            };

            var json = JsonSerializer.Serialize(requestBody);
            var response = await client.PostAsync(_apiUrl, new StringContent(json, Encoding.UTF8, "application/json"));

            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("AI API returned {Status}", response.StatusCode);
                return Enumerable.Repeat(Guid.Empty, items.Count).ToList();
            }

            var responseJson = await response.Content.ReadAsStringAsync();
            var aiResponse = JsonSerializer.Deserialize<AiChatResponse>(responseJson);
            var content = aiResponse?.Choices?.FirstOrDefault()?.Message?.Content ?? "[]";

            var extractedJson = ExtractJsonArray(content);
            var categoryIds = JsonSerializer.Deserialize<List<string?>>(extractedJson) ?? [];

            return categoryIds.Select(id =>
                id is not null && Guid.TryParse(id, out var guid) ? guid : Guid.Empty
            ).ToList();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "AI categorization failed");
            return Enumerable.Repeat(Guid.Empty, items.Count).ToList();
        }
    }

    private static string ExtractJsonArray(string content)
    {
        var start = content.IndexOf('[');
        var end = content.LastIndexOf(']');
        return start >= 0 && end > start ? content[start..(end + 1)] : "[]";
    }

    private record AiChatResponse([property: JsonPropertyName("choices")] List<AiChoice>? Choices);
    private record AiChoice([property: JsonPropertyName("message")] AiMessage? Message);
    private record AiMessage([property: JsonPropertyName("content")] string? Content);
}
