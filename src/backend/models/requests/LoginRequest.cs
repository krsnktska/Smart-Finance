using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record LoginRequest(
    [Required][EmailAddress] string Email,
    [Required] string Password);
