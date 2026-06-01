using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using SmartFinance.Services.Interfaces;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Jpeg;

namespace SmartFinance.Services;

public class OcrService(IConfiguration configuration, IHttpClientFactory httpClientFactory, ILogger<OcrService> logger) : IOcrService
{
    private readonly string _apiKey = configuration["Claude:ApiKey"] ?? string.Empty;
    private readonly string _apiUrl = configuration["Claude:ApiUrl"] ?? "https://api.anthropic.com/v1/messages";
    private readonly string _model = configuration["Claude:Model"] ?? "claude-3-5-sonnet-20241022";

    public async Task<string> ExtractTextAsync(Stream imageStream)
    {
        if (string.IsNullOrEmpty(_apiKey))
        {
            logger.LogWarning("Claude API Key is not configured. Receipt scanning will not work.");
            throw new InvalidOperationException("Claude API Key is not configured.");
        }

        try
        {
            if (imageStream.CanSeek)
            {
                imageStream.Position = 0;
            }

            // 1. Preprocess the image using ImageSharp to minimize network payload size
            byte[] imageBytes;
            using (var ms = new MemoryStream())
            {
                using (var image = await Image.LoadAsync(imageStream))
                {
                    // Scale down to 1200px width if it's very large
                    const int maxScaleWidth = 1200;
                    if (image.Width > maxScaleWidth)
                    {
                        int width = maxScaleWidth;
                        int height = (int)((double)image.Height / image.Width * width);
                        image.Mutate(x => x.Resize(width, height));
                    }

                    // Convert to grayscale to reduce size
                    image.Mutate(x => x.Grayscale());

                    // Compress to JPEG with 75% quality
                    await image.SaveAsync(ms, new JpegEncoder { Quality = 75 });
                }
                imageBytes = ms.ToArray();
            }

            var base64Data = Convert.ToBase64String(imageBytes);
            var mediaType = "image/jpeg"; // Always JPEG after our ImageSharp preprocessing!

            var promptText = "Analyze this receipt image. Extract all details and return it strictly as a JSON object matching this schema:\n" +
                             "{\n" +
                             "  \"StoreName\": \"Name of the store/merchant\",\n" +
                             "  \"OccurredAt\": \"ISO 8601 date-time string in UTC, e.g. 2026-06-01T16:49:25Z (try to find the transaction date and time on the receipt)\",\n" +
                             "  \"Total\": 97.49,\n" +
                             "  \"Currency\": \"UAH\", // or other code like USD, EUR\n" +
                             "  \"Items\": [\n" +
                             "    {\n" +
                             "      \"Name\": \"Item Name\",\n" +
                             "      \"Quantity\": 1.0,\n" +
                             "      \"Unit\": \"шт\", // or other unit name like null or 'гр'\n" +
                             "      \"UnitPrice\": 67.50,\n" +
                             "      \"TotalPrice\": 67.50\n" +
                             "    }\n" +
                             "  ]\n" +
                             "}\n" +
                             "Return ONLY the raw JSON object. Do not include markdown formatting or backticks around it.";

            var client = httpClientFactory.CreateClient();
            client.DefaultRequestHeaders.Add("x-api-key", _apiKey);
            client.DefaultRequestHeaders.Add("anthropic-version", "2023-06-01");

            var requestBody = new
            {
                model = _model,
                max_tokens = 2048,
                messages = new[]
                {
                    new
                    {
                        role = "user",
                        content = new object[]
                        {
                            new
                            {
                                type = "image",
                                source = new
                                {
                                    type = "base64",
                                    media_type = mediaType,
                                    data = base64Data
                                }
                            },
                            new
                            {
                                type = "text",
                                text = promptText
                            }
                        }
                    }
                }
            };

            var jsonBody = JsonSerializer.Serialize(requestBody);
            var httpResponse = await client.PostAsync(_apiUrl, new StringContent(jsonBody, Encoding.UTF8, "application/json"));

            if (!httpResponse.IsSuccessStatusCode)
            {
                var errorText = await httpResponse.Content.ReadAsStringAsync();
                logger.LogError("Claude API returned error {Status}: {Error}", httpResponse.StatusCode, errorText);
                throw new Exception($"Claude API error: {httpResponse.StatusCode}");
            }

            var responseJson = await httpResponse.Content.ReadAsStringAsync();
            var claudeResponse = JsonSerializer.Deserialize<ClaudeResponse>(responseJson);
            var content = claudeResponse?.Content?.FirstOrDefault()?.Text ?? "{}";

            var jsonObject = ExtractJsonObject(content);
            logger.LogInformation("Successfully parsed receipt via Claude Vision API");
            return jsonObject;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Claude Vision OCR failed");
            throw;
        }
    }

    private static string ExtractJsonObject(string content)
    {
        var start = content.IndexOf('{');
        var end = content.LastIndexOf('}');
        return start >= 0 && end > start ? content[start..(end + 1)] : "{}";
    }

    private record ClaudeResponse([property: JsonPropertyName("content")] List<ClaudeContent>? Content);
    private record ClaudeContent([property: JsonPropertyName("text")] string? Text);
}
