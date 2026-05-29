using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IGroupInvitationService
{
    Task<ServiceResult<GroupInvitationResponse>> InviteAsync(Guid groupId, Guid inviterId, Guid inviteeId);
    Task<ServiceResult<List<GroupInvitationResponse>>> GetMyPendingAsync(Guid userId);
    Task<ServiceResult<List<GroupInvitationResponse>>> GetGroupInvitationsAsync(Guid groupId, Guid requesterId);
    Task<ServiceResult> AcceptAsync(Guid invitationId, Guid userId);
    Task<ServiceResult> DeclineAsync(Guid invitationId, Guid userId);
}
