namespace SmartFinance.Services.Interfaces;

public interface IOcrService
{
    Task<string> ExtractTextAsync(Stream imageStream);
}
