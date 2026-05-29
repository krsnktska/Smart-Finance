namespace SmartFinance.Models.Responses;

public record GroupInvitationResponse(
    Guid Id,
    Guid GroupId,
    string GroupName,
    Guid InvitedUserId,
    string InvitedUserName,
    string InvitedUserEmail,
    Guid InvitedByUserId,
    string InvitedByUserName,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? RespondedAt
);
