using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("gmail_tokens")]
public class GmailToken
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("user_id")]
    public Guid UserId { get; set; }

    [Required]
    [Column("access_token")]
    public string AccessToken { get; set; } = null!;

    [Column("refresh_token")]
    public string? RefreshToken { get; set; }

    [Column("token_expiry")]
    public DateTimeOffset TokenExpiry { get; set; }

    [Required]
    [Column("gmail_address")]
    public string GmailAddress { get; set; } = null!;

    [Column("last_scanned_at")]
    public DateTimeOffset? LastScannedAt { get; set; }

    public User User { get; set; } = null!;
}
