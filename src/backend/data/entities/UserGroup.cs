using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("user_groups")]
public class UserGroup
{
    [Column("user_id")]
    public Guid UserId { get; set; }

    [Column("group_id")]
    public Guid GroupId { get; set; }

    [Required]
    [Column("is_owner")]
    public bool IsOwner { get; set; }

    public User User { get; set; } = null!;
    public Group Group { get; set; } = null!;
}
