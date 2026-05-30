using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class GroupService(SmartFinanceDbContext context) : IGroupService
{
    public async Task<List<GroupResponse>> GetAllAsync(Guid userId)
    {
        var groups = await context.Groups
            .Where(g => g.UserGroups.Any(ug => ug.UserId == userId))
            .Include(g => g.UserGroups)
                .ThenInclude(ug => ug.User)
            .ToListAsync();

        return groups.Select(MapGroup).ToList();
    }

    public async Task<ServiceResult<GroupResponse>> GetByIdAsync(Guid id, Guid userId)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
                .ThenInclude(ug => ug.User)
            .FirstOrDefaultAsync(g => g.Id == id && g.UserGroups.Any(ug => ug.UserId == userId));

        if (group is null) return ServiceResult<GroupResponse>.NotFound();

        return ServiceResult<GroupResponse>.Ok(MapGroup(group));
    }

    public async Task<GroupResponse> CreateAsync(Guid userId, CreateGroupRequest request)
    {
        var group = new Group
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            UserGroups = [new UserGroup { UserId = userId, IsOwner = true }]
        };

        context.Groups.Add(group);
        await context.SaveChangesAsync();

        await context.Entry(group).Collection(g => g.UserGroups).Query()
            .Include(ug => ug.User).LoadAsync();

        return MapGroup(group);
    }

    public async Task<ServiceResult<GroupResponse>> UpdateAsync(Guid id, Guid userId, UpdateGroupRequest request)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
                .ThenInclude(ug => ug.User)
            .FirstOrDefaultAsync(g => g.Id == id && g.UserGroups.Any(ug => ug.UserId == userId));

        if (group is null) return ServiceResult<GroupResponse>.NotFound();

        var membership = group.UserGroups.First(ug => ug.UserId == userId);
        if (!membership.IsOwner) return ServiceResult<GroupResponse>.Forbidden();

        group.Name = request.Name;
        await context.SaveChangesAsync();

        return ServiceResult<GroupResponse>.Ok(MapGroup(group));
    }

    public async Task<ServiceResult> DeleteAsync(Guid id, Guid userId)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
            .FirstOrDefaultAsync(g => g.Id == id && g.UserGroups.Any(ug => ug.UserId == userId));

        if (group is null) return ServiceResult.NotFound();

        var membership = group.UserGroups.First(ug => ug.UserId == userId);
        if (!membership.IsOwner) return ServiceResult.Forbidden();

        context.Groups.Remove(group);
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }

    public async Task<ServiceResult> AddMemberAsync(Guid groupId, Guid currentUserId, Guid targetUserId)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
            .FirstOrDefaultAsync(g => g.Id == groupId && g.UserGroups.Any(ug => ug.UserId == currentUserId));

        if (group is null) return ServiceResult.NotFound();

        var membership = group.UserGroups.First(ug => ug.UserId == currentUserId);
        if (!membership.IsOwner) return ServiceResult.Forbidden();

        if (group.UserGroups.Any(ug => ug.UserId == targetUserId))
            return ServiceResult.BadRequest();

        var targetUser = await context.Users.FindAsync(targetUserId);
        if (targetUser is null) return ServiceResult.NotFound();

        context.UserGroups.Add(new UserGroup { UserId = targetUserId, GroupId = groupId, IsOwner = false });
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }

    public async Task<ServiceResult> RemoveMemberAsync(Guid groupId, Guid currentUserId, Guid targetUserId)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
            .FirstOrDefaultAsync(g => g.Id == groupId && g.UserGroups.Any(ug => ug.UserId == currentUserId));

        if (group is null) return ServiceResult.NotFound();

        var requesterMembership = group.UserGroups.First(ug => ug.UserId == currentUserId);
        if (!requesterMembership.IsOwner) return ServiceResult.Forbidden();

        var targetMembership = group.UserGroups.FirstOrDefault(ug => ug.UserId == targetUserId);
        if (targetMembership is null) return ServiceResult.NotFound();
        if (targetMembership.IsOwner) return ServiceResult.BadRequest();

        context.UserGroups.Remove(targetMembership);
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }

    public async Task<ServiceResult> LeaveAsync(Guid groupId, Guid userId)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
            .FirstOrDefaultAsync(g => g.Id == groupId && g.UserGroups.Any(ug => ug.UserId == userId));

        if (group is null) return ServiceResult.NotFound();

        var membership = group.UserGroups.First(ug => ug.UserId == userId);
        if (membership.IsOwner) return ServiceResult.Forbidden();

        context.UserGroups.Remove(membership);
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }

    public async Task<ServiceResult<List<AccountResponse>>> GetAccountsAsync(Guid groupId, Guid userId)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
            .Include(g => g.AccountGroups)
                .ThenInclude(ag => ag.Account)
            .FirstOrDefaultAsync(g => g.Id == groupId && g.UserGroups.Any(ug => ug.UserId == userId));

        if (group is null) return ServiceResult<List<AccountResponse>>.NotFound();

        var accounts = group.AccountGroups
            .Select(ag => new AccountResponse(
                ag.Account.Id, ag.Account.Name, ag.Account.Currency, ag.Account.UserId))
            .ToList();

        return ServiceResult<List<AccountResponse>>.Ok(accounts);
    }

    public async Task<ServiceResult> AddAccountAsync(Guid groupId, Guid userId, Guid accountId)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
            .Include(g => g.AccountGroups)
            .FirstOrDefaultAsync(g => g.Id == groupId && g.UserGroups.Any(ug => ug.UserId == userId));

        if (group is null) return ServiceResult.NotFound();

        var membership = group.UserGroups.First(ug => ug.UserId == userId);
        if (!membership.IsOwner) return ServiceResult.Forbidden();

        if (group.AccountGroups.Any(ag => ag.AccountId == accountId))
            return ServiceResult.Conflict();

        var account = await context.Accounts
            .FirstOrDefaultAsync(a => a.Id == accountId && a.UserId == userId);

        if (account is null) return ServiceResult.NotFound();

        context.AccountGroups.Add(new AccountGroup { AccountId = accountId, GroupId = groupId });
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }

    public async Task<ServiceResult> RemoveAccountAsync(Guid groupId, Guid userId, Guid accountId)
    {
        var group = await context.Groups
            .Include(g => g.UserGroups)
            .Include(g => g.AccountGroups)
            .FirstOrDefaultAsync(g => g.Id == groupId && g.UserGroups.Any(ug => ug.UserId == userId));

        if (group is null) return ServiceResult.NotFound();

        var membership = group.UserGroups.First(ug => ug.UserId == userId);
        if (!membership.IsOwner) return ServiceResult.Forbidden();

        var accountGroup = group.AccountGroups.FirstOrDefault(ag => ag.AccountId == accountId);
        if (accountGroup is null) return ServiceResult.NotFound();

        context.AccountGroups.Remove(accountGroup);
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }

    private static GroupResponse MapGroup(Group g) =>
        new(g.Id, g.Name, g.UserGroups
            .Select(ug => new GroupMemberResponse(ug.UserId, ug.User.Name, ug.User.Email, ug.IsOwner))
            .ToList());
}
