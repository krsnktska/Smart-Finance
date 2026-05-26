using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("transaction_categories")]
public class TransactionCategory
{
    [Column("transaction_id")]
    public Guid TransactionId { get; set; }

    [Column("category_id")]
    public Guid CategoryId { get; set; }

    public Transaction Transaction { get; set; } = null!;
    public Category Category { get; set; } = null!;
}
