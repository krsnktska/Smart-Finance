using SmartFinance.Models;

namespace SmartFinance.Services.Interfaces;

public interface IReceiptScraperService
{
    Task<ParsedReceipt?> ScrapeAsync(string url);
}
