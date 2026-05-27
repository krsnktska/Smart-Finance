namespace SmartFinance.Models.Responses;

public record GroupMemberResponse(Guid UserId, string Name, string Email, bool IsOwner);

public record GroupResponse(Guid Id, string Name, List<GroupMemberResponse> Members);
