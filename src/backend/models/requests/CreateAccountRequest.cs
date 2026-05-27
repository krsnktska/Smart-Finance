using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record CreateAccountRequest(
    [Required] string Name,
    [Required] string Currency);
