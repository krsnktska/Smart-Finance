using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("groups")]
public class Group
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("name")]
    public string Name { get; set; } = null!;

    public ICollection<UserGroup> UserGroups { get; set; } = [];
    public ICollection<AccountGroup> AccountGroups { get; set; } = [];
}
