namespace SmartFinance.Models.Responses;

public record CategoryResponse(Guid Id, string Name, string Color, string? Emoji, Guid? UserId);
