using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("bank_integrations")]
public class BankIntegration
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("user_id")]
    public Guid UserId { get; set; }

    [Required]
    [Column("bank_type")]
    public BankType BankType { get; set; }

    [Required]
    [Column("api_token")]
    public string ApiToken { get; set; } = null!;

    [Required]
    [Column("account_id")]
    public Guid AccountId { get; set; }

    [Column("bank_account_id")]
    public string? BankAccountId { get; set; }

    [Column("last_synced_at")]
    public DateTimeOffset? LastSyncedAt { get; set; }

    public User User { get; set; } = null!;
    public Account Account { get; set; } = null!;
}
