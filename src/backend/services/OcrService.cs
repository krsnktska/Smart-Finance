using SmartFinance.Services.Interfaces;
using Tesseract;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Jpeg;

namespace SmartFinance.Services;

public class OcrService(IConfiguration configuration, ILogger<OcrService> logger) : IOcrService
{
    private readonly string _tessDataPath = configuration["Ocr:TessDataPath"] ?? "tessdata";
    private readonly string _languages = configuration["Ocr:Languages"] ?? "ukr+eng";

    public async Task<string> ExtractTextAsync(Stream imageStream)
    {
        var tempFile = Path.GetTempFileName();
        try
        {
            if (imageStream.CanSeek)
            {
                imageStream.Position = 0;
            }

            // Load and preprocess the image using ImageSharp
            await using (var fs = File.Create(tempFile))
            {
                using (var image = await Image.LoadAsync(imageStream))
                {
                    // Proportional resize to 1200px width if it's too large
                    const int maxScaleWidth = 1200;
                    if (image.Width > maxScaleWidth)
                    {
                        int width = maxScaleWidth;
                        int height = (int)((double)image.Height / image.Width * width);
                        image.Mutate(x => x.Resize(width, height));
                    }

                    // Convert to grayscale to optimize OCR and reduce file size
                    image.Mutate(x => x.Grayscale());

                    // Save as highly compressed JPEG
                    await image.SaveAsync(fs, new JpegEncoder { Quality = 75 });
                }
            }

            using var engine = new TesseractEngine(_tessDataPath, _languages, EngineMode.Default);
            using var img = Pix.LoadFromFile(tempFile);
            using var page = engine.Process(img);

            var text = page.GetText();
            logger.LogInformation("OCR extracted {Chars} characters", text.Length);
            return text;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "OCR failed");
            throw;
        }
        finally
        {
            File.Delete(tempFile);
        }
    }
}
