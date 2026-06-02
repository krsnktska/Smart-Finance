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
    private readonly string _apiUrl = configuration["AI:ApiUrl"] ?? "https://generativelanguage.googleapis.com/v1beta/models/{0}:generateContent?key={1}";
    private readonly string _model = configuration["AI:Model"] ?? "gemini-2.5-flash";

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

            var requestBody = new
            {
                contents = new[]
                {
                    new
                    {
                        role = "user",
                        parts = new[] { new { text = userPrompt } }
                    }
                },
                systemInstruction = new
                {
                    parts = new[] { new { text = systemPrompt } }
                },
                generationConfig = new
                {
                    temperature = 0,
                    maxOutputTokens = 500,
                    responseMimeType = "application/json"
                }
            };

            var json = JsonSerializer.Serialize(requestBody);
            
            // Format URL with model and api key
            var url = string.Format(_apiUrl, _model, _apiKey);
            var response = await client.PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json"));

            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                logger.LogWarning("Gemini API returned {Status}. Body: {Body}", response.StatusCode, errorBody);
                return Enumerable.Repeat(Guid.Empty, items.Count).ToList();
            }

            var responseJson = await response.Content.ReadAsStringAsync();
            var aiResponse = JsonSerializer.Deserialize<GeminiResponse>(responseJson);
            var content = aiResponse?.Candidates?.FirstOrDefault()?.Content?.Parts?.FirstOrDefault()?.Text ?? "[]";

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

    private record GeminiResponse([property: JsonPropertyName("candidates")] List<GeminiCandidate>? Candidates);
    private record GeminiCandidate([property: JsonPropertyName("content")] GeminiContent? Content);
    private record GeminiContent([property: JsonPropertyName("parts")] List<GeminiPart>? Parts);
    private record GeminiPart([property: JsonPropertyName("text")] string? Text);
}
