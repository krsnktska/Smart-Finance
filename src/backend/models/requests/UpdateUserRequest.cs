namespace SmartFinance.Models.Requests;

public record UpdateUserRequest(string? Name, DateOnly? Birthday);
