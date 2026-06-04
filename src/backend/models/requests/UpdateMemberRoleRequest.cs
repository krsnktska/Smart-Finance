namespace SmartFinance.Models.Requests;

public record UpdateMemberRoleRequest(bool IsOwner, bool? CanView, bool? CanWrite);
