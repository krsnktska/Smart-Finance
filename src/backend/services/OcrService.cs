using SmartFinance.Services.Interfaces;
using Tesseract;

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
            await using (var fs = File.Create(tempFile))
                await imageStream.CopyToAsync(fs);

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
