namespace SmartFinance.Models.Responses;

public record AuthResponse(string Token, string RefreshToken, UserResponse User);
