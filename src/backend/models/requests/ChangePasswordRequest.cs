using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record ChangePasswordRequest(
    [Required] string CurrentPassword,
    [Required][MinLength(6)] string NewPassword);
