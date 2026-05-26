using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("categories")]
public class Category
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("name")]
    public string Name { get; set; } = null!;

    [Required]
    [Column("color")]
    public string Color { get; set; } = null!;

    [Column("emoji")]
    public string? Emoji { get; set; }

    [Column("user_id")]
    public Guid? UserId { get; set; }

    public User? User { get; set; }
    public ICollection<TransactionCategory> TransactionCategories { get; set; } = [];
}
