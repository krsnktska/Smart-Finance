namespace SmartFinance.Models.Responses;

public record UserResponse(Guid Id, string Name, string Email, DateOnly? Birthday);
