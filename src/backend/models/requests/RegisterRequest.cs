using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record RegisterRequest(
    [Required] string Name,
    [Required][EmailAddress] string Email,
    [Required][MinLength(6)] string Password,
    DateOnly? Birthday);
