namespace SmartFinance.Models.Requests;

public record ScrapeReceiptRequest(string Url, Guid AccountId);
