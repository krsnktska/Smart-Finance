using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("group_invitations")]
public class GroupInvitation
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("group_id")]
    public Guid GroupId { get; set; }

    [Required]
    [Column("invited_user_id")]
    public Guid InvitedUserId { get; set; }

    [Required]
    [Column("invited_by_user_id")]
    public Guid InvitedByUserId { get; set; }

    [Required]
    [Column("status")]
    public InvitationStatus Status { get; set; } = InvitationStatus.Pending;

    [Required]
    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("responded_at")]
    public DateTimeOffset? RespondedAt { get; set; }

    public Group Group { get; set; } = null!;
    public User InvitedUser { get; set; } = null!;
    public User InvitedByUser { get; set; } = null!;
}
