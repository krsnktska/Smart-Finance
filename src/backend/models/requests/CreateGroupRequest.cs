using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record CreateGroupRequest([Required] string Name);
