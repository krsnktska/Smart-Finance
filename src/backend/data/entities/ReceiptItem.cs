using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("receipt_items")]
public class ReceiptItem
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("transaction_id")]
    public Guid TransactionId { get; set; }

    [Required]
    [Column("name")]
    public string Name { get; set; } = null!;

    [Column("quantity")]
    public decimal Quantity { get; set; } = 1;

    [Column("unit")]
    public string? Unit { get; set; }

    [Column("unit_price")]
    public decimal UnitPrice { get; set; }

    [Column("total_price")]
    public decimal TotalPrice { get; set; }

    public Transaction Transaction { get; set; } = null!;
}
