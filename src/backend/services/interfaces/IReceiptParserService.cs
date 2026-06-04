using SmartFinance.Models;

namespace SmartFinance.Services.Interfaces;

public interface IReceiptParserService
{
    Task<ParsedReceipt> ParseAsync(string ocrText);
}
