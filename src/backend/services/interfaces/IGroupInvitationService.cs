using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IGroupInvitationService
{
    Task<ServiceResult<GroupInvitationResponse>> InviteByEmailAsync(Guid groupId, Guid inviterId, string email);
    Task<ServiceResult<List<GroupInvitationResponse>>> GetMyPendingAsync(Guid userId);
    Task<ServiceResult<List<GroupInvitationResponse>>> GetGroupInvitationsAsync(Guid groupId, Guid requesterId);
    Task<ServiceResult> AcceptAsync(Guid invitationId, Guid userId);
    Task<ServiceResult> DeclineAsync(Guid invitationId, Guid userId);
    Task<ServiceResult> CancelAsync(Guid invitationId, Guid requesterId);
}
