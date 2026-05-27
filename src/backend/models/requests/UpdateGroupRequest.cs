using System.ComponentModel.DataAnnotations;

namespace SmartFinance.Models.Requests;

public record UpdateGroupRequest([Required] string Name);
