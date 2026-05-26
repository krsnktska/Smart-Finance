using System.ComponentModel.DataAnnotations.Schema;

namespace SmartFinance.Models;

[Table("account_groups")]
public class AccountGroup
{
    [Column("account_id")]
    public Guid AccountId { get; set; }

    [Column("group_id")]
    public Guid GroupId { get; set; }

    public Account Account { get; set; } = null!;
    public Group Group { get; set; } = null!;
}
