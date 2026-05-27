using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("refresh_tokens")]
public class RefreshToken
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("token")]
    public string Token { get; set; } = null!;

    [Column("user_id")]
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    [Required]
    [Column("expires_at")]
    public DateTimeOffset ExpiresAt { get; set; }

    [Required]
    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; }

    [Column("is_revoked")]
    public bool IsRevoked { get; set; }
}
