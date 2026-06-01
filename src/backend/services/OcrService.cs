using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;
using SmartFinance.Services.Interfaces;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Jpeg;

namespace SmartFinance.Services;

public class OcrService(IConfiguration configuration, IHttpClientFactory httpClientFactory, ILogger<OcrService> logger) : IOcrService
{
    private readonly string _apiKey = configuration["Ocr:ApiKey"] ?? "helloworld";
    private readonly string _apiUrl = configuration["Ocr:ApiUrl"] ?? "https://api.ocr.space/parse/image";
    private readonly string _language = configuration["Ocr:Language"] ?? "auto";

    public async Task<string> ExtractTextAsync(Stream imageStream)
    {
        try
        {
            if (imageStream.CanSeek)
            {
                imageStream.Position = 0;
            }

            // 1. Preprocess the image using ImageSharp to minimize network payload size and improve OCR speed
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

                    // Convert to grayscale to reduce size and improve OCR contrast
                    image.Mutate(x => x.Grayscale());

                    // Compress to JPEG with 75% quality
                    await image.SaveAsync(ms, new JpegEncoder { Quality = 75 });
                }
                imageBytes = ms.ToArray();
            }

            // 2. Call OCR.space API using multipart/form-data
            var client = httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(30);

            using var content = new MultipartFormDataContent();
            
            var fileContent = new ByteArrayContent(imageBytes);
            fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
            content.Add(fileContent, "file", "receipt.jpg");

            content.Add(new StringContent(_apiKey), "apikey");
            content.Add(new StringContent(_language), "language");
            content.Add(new StringContent("2"), "OCREngine"); // Use OCR Engine 2 for superior layout & Ukrainian support
            content.Add(new StringContent("true"), "isTable");
            content.Add(new StringContent("true"), "isOverlayRequired"); // Required to avoid empty text results in Engine 2
            content.Add(new StringContent("true"), "scale");

            logger.LogInformation("Sending receipt image to OCR.space API (Engine: 2, Language: {Lang})", _language);
            var httpResponse = await client.PostAsync(_apiUrl, content);

            if (!httpResponse.IsSuccessStatusCode)
            {
                var errorText = await httpResponse.Content.ReadAsStringAsync();
                logger.LogError("OCR.space API returned error {Status}: {Error}", httpResponse.StatusCode, errorText);
                throw new Exception($"OCR.space API error: {httpResponse.StatusCode}");
            }

            var responseJson = await httpResponse.Content.ReadAsStringAsync();
            var ocrResponse = JsonSerializer.Deserialize<OcrSpaceResponse>(responseJson);

            if (ocrResponse == null)
            {
                throw new Exception("Failed to deserialize OCR.space response.");
            }

            if (ocrResponse.IsErroredOnProcessing || ocrResponse.OcrExitCode != 1)
            {
                var errorMsg = ocrResponse.ErrorMessage?.ToString() ?? "Unknown OCR.space processing error";
                logger.LogError("OCR.space processing error: {Error}", errorMsg);
                throw new Exception($"OCR.space error: {errorMsg}");
            }

            var extractedText = ocrResponse.ParsedResults?.FirstOrDefault()?.ParsedText ?? string.Empty;
            logger.LogInformation("Successfully extracted {Chars} characters via OCR.space API", extractedText.Length);
            
            return extractedText;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "OCR.space request failed");
            throw;
        }
    }

    private record OcrSpaceResponse(
        [property: JsonPropertyName("ParsedResults")] List<OcrSpaceParsedResult>? ParsedResults,
        [property: JsonPropertyName("OCRExitCode")] int OcrExitCode,
        [property: JsonPropertyName("IsErroredOnProcessing")] bool IsErroredOnProcessing,
        [property: JsonPropertyName("ErrorMessage")] object? ErrorMessage,
        [property: JsonPropertyName("ErrorDetails")] object? ErrorDetails
    );

    private record OcrSpaceParsedResult(
        [property: JsonPropertyName("ParsedText")] string? ParsedText
    );
}
