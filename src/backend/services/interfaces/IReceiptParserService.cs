using SmartFinance.Models;

namespace SmartFinance.Services.Interfaces;

public interface IReceiptParserService
{
    ParsedReceipt Parse(string ocrText);
}
