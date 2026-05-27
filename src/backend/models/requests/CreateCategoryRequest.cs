using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record CreateCategoryRequest(
    [Required] string Name,
    [Required] string Color,
    string? Emoji);
