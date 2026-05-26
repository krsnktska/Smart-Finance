using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("transactions")]
public class Transaction
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("type")]
    public TransactionType Type { get; set; }

    [Column("special_type")]
    public SpecialType? SpecialType { get; set; }

    [Required]
    [Column("value")]
    public decimal Value { get; set; }

    [Required]
    [Column("occurred_at")]
    public DateTimeOffset OccurredAt { get; set; }

    [Required]
    [Column("name")]
    public string Name { get; set; } = null!;

    [Column("description")]
    public string? Description { get; set; }

    [Required]
    [Column("currency")]
    public string Currency { get; set; } = null!;

    [Column("account_id")]
    public Guid AccountId { get; set; }

    public Account Account { get; set; } = null!;
    public ICollection<TransactionCategory> TransactionCategories { get; set; } = [];
}
