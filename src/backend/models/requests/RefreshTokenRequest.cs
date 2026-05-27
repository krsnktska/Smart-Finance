using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record RefreshTokenRequest([Required] string RefreshToken);
