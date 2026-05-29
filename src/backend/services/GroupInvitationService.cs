using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class GroupInvitationService(SmartFinanceDbContext context) : IGroupInvitationService
{
    public async Task<ServiceResult<GroupInvitationResponse>> InviteByEmailAsync(Guid groupId, Guid inviterId, string email)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
            .FirstOrDefaultAsync(g => g.Id == groupId && g.UserGroups.Any(ug => ug.UserId == inviterId));

        if (group is null) return ServiceResult<GroupInvitationResponse>.NotFound();

        if (!group.UserGroups.First(ug => ug.UserId == inviterId).IsOwner)
            return ServiceResult<GroupInvitationResponse>.Forbidden();

        var invitee = await context.Users.FirstOrDefaultAsync(u => u.Email == email.ToLower());
        if (invitee is null) return ServiceResult<GroupInvitationResponse>.NotFound();

        var inviteeId = invitee.Id;

        if (group.UserGroups.Any(ug => ug.UserId == inviteeId))
            return ServiceResult<GroupInvitationResponse>.Conflict();

        // не створювати дублікат якщо вже є активне запрошення
        var existingPending = await context.GroupInvitations
            .AnyAsync(gi => gi.GroupId == groupId && gi.InvitedUserId == inviteeId && gi.Status == InvitationStatus.Pending);

        if (existingPending) return ServiceResult<GroupInvitationResponse>.Conflict();

        var inviter = await context.Users.FindAsync(inviterId);

        var invitation = new GroupInvitation
        {
            Id = Guid.NewGuid(),
            GroupId = groupId,
            InvitedUserId = inviteeId,
            InvitedByUserId = inviterId,
            Status = InvitationStatus.Pending,
            CreatedAt = DateTimeOffset.UtcNow
        };

        context.GroupInvitations.Add(invitation);
        await context.SaveChangesAsync();

        return ServiceResult<GroupInvitationResponse>.Ok(Map(invitation, group, invitee!, inviter!));
    }

    public async Task<ServiceResult<List<GroupInvitationResponse>>> GetMyPendingAsync(Guid userId)
    {
        var invitations = await context.GroupInvitations
            .Where(gi => gi.InvitedUserId == userId && gi.Status == InvitationStatus.Pending)
            .Include(gi => gi.Group)
            .Include(gi => gi.InvitedUser)
            .Include(gi => gi.InvitedByUser)
            .OrderByDescending(gi => gi.CreatedAt)
            .ToListAsync();

        return ServiceResult<List<GroupInvitationResponse>>.Ok(invitations.Select(Map).ToList());
    }

    public async Task<ServiceResult<List<GroupInvitationResponse>>> GetGroupInvitationsAsync(Guid groupId, Guid requesterId)
    {
        var isMember = await context.Groups
            .AnyAsync(g => g.Id == groupId && g.UserGroups.Any(ug => ug.UserId == requesterId && ug.IsOwner));

        if (!isMember) return ServiceResult<List<GroupInvitationResponse>>.Forbidden();

        var invitations = await context.GroupInvitations
            .Where(gi => gi.GroupId == groupId)
            .Include(gi => gi.Group)
            .Include(gi => gi.InvitedUser)
            .Include(gi => gi.InvitedByUser)
            .OrderByDescending(gi => gi.CreatedAt)
            .ToListAsync();

        return ServiceResult<List<GroupInvitationResponse>>.Ok(invitations.Select(Map).ToList());
    }

    public async Task<ServiceResult> AcceptAsync(Guid invitationId, Guid userId)
    {
        var invitation = await context.GroupInvitations
            .FirstOrDefaultAsync(gi => gi.Id == invitationId && gi.InvitedUserId == userId);

        if (invitation is null) return ServiceResult.NotFound();
        if (invitation.Status != InvitationStatus.Pending) return ServiceResult.BadRequest();

        invitation.Status = InvitationStatus.Accepted;
        invitation.RespondedAt = DateTimeOffset.UtcNow;

        context.UserGroups.Add(new UserGroup
        {
            UserId = userId,
            GroupId = invitation.GroupId,
            IsOwner = false
        });

        await context.SaveChangesAsync();
        return ServiceResult.Ok();
    }

    public async Task<ServiceResult> DeclineAsync(Guid invitationId, Guid userId)
    {
        var invitation = await context.GroupInvitations
            .FirstOrDefaultAsync(gi => gi.Id == invitationId && gi.InvitedUserId == userId);

        if (invitation is null) return ServiceResult.NotFound();
        if (invitation.Status != InvitationStatus.Pending) return ServiceResult.BadRequest();

        invitation.Status = InvitationStatus.Declined;
        invitation.RespondedAt = DateTimeOffset.UtcNow;

        await context.SaveChangesAsync();
        return ServiceResult.Ok();
    }

    private static GroupInvitationResponse Map(GroupInvitation gi) =>
        Map(gi, gi.Group, gi.InvitedUser, gi.InvitedByUser);

    private static GroupInvitationResponse Map(GroupInvitation gi, Group group, User invitedUser, User invitedBy) =>
        new(gi.Id, gi.GroupId, group.Name,
            gi.InvitedUserId, invitedUser.Name, invitedUser.Email,
            gi.InvitedByUserId, invitedBy.Name,
            gi.Status.ToString(),
            gi.CreatedAt, gi.RespondedAt);
}
