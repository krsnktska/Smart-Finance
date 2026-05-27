namespace SmartFinance.Models.Responses;

public record AccountResponse(Guid Id, string Name, string Currency, Guid UserId);
