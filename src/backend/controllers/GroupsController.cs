using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Manages shared groups that allow multiple users to access shared accounts.
/// </summary>
[ApiController]
[Route("api/groups")]
[Authorize]
[Produces("application/json")]
public class GroupsController(IGroupService groupService) : ControllerBase
{
    /// <summary>
    /// Returns all groups the authenticated user is a member of.
    /// </summary>
    /// <returns>List of groups.</returns>
    /// <response code="200">Groups returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    [HttpGet]
    [ProducesResponseType(typeof(List<GroupResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetAll() =>
        Ok(await groupService.GetAllAsync(GetCurrentUserId()));

    /// <summary>
    /// Returns a single group by its identifier.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <returns>Group data including its members.</returns>
    /// <response code="200">Group returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Group not found or user is not a member.</response>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(GroupResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(Guid id)
    {
        var result = await groupService.GetByIdAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Creates a new group. The authenticated user becomes the owner.
    /// </summary>
    /// <param name="request">Group creation data.</param>
    /// <returns>Newly created group.</returns>
    /// <response code="201">Group created successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    [HttpPost]
    [ProducesResponseType(typeof(GroupResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Create([FromBody] CreateGroupRequest request)
    {
        var group = await groupService.CreateAsync(GetCurrentUserId(), request);
        return CreatedAtAction(nameof(GetById), new { id = group.Id }, group);
    }

    /// <summary>
    /// Updates the name of a group. Only the group owner can perform this action.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <param name="request">New group name.</param>
    /// <returns>Updated group data.</returns>
    /// <response code="200">Group updated successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="403">User is not the owner of the group.</response>
    /// <response code="404">Group not found or user is not a member.</response>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(GroupResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateGroupRequest request)
    {
        var result = await groupService.UpdateAsync(id, GetCurrentUserId(), request);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Deletes a group. Only the group owner can perform this action.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <response code="204">Group deleted successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="403">User is not the owner of the group.</response>
    /// <response code="404">Group not found or user is not a member.</response>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id)
    {
        var result = await groupService.DeleteAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Adds a user to a group. Only the group owner can perform this action.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <param name="userId">Identifier of the user to add.</param>
    /// <response code="204">User added to the group successfully.</response>
    /// <response code="400">User is already a member of the group.</response>
    /// <response code="401">Requester is not authenticated.</response>
    /// <response code="403">Requester is not the owner of the group.</response>
    /// <response code="404">Group or target user not found.</response>
    [HttpPost("{id:guid}/members/{userId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> AddMember(Guid id, Guid userId)
    {
        var result = await groupService.AddMemberAsync(id, GetCurrentUserId(), userId);
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            ServiceStatus.BadRequest => BadRequest(new { message = "User is already a member of this group." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Removes a user from a group. Only the group owner can perform this action.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <param name="userId">Identifier of the user to remove.</param>
    /// <response code="204">User removed from the group successfully.</response>
    /// <response code="400">Cannot remove the owner from the group.</response>
    /// <response code="401">Requester is not authenticated.</response>
    /// <response code="403">Requester is not the owner of the group.</response>
    /// <response code="404">Group or membership not found.</response>
    [HttpDelete("{id:guid}/members/{userId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RemoveMember(Guid id, Guid userId)
    {
        var result = await groupService.RemoveMemberAsync(id, GetCurrentUserId(), userId);
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            ServiceStatus.BadRequest => BadRequest(new { message = "Cannot remove the owner from the group." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Allows the authenticated user to leave a group they are a member of.
    /// The group owner cannot leave — they must delete the group instead.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <response code="204">User left the group successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="403">User is the owner of the group and cannot leave.</response>
    /// <response code="404">Group not found or user is not a member.</response>
    [HttpDelete("{id:guid}/members/me")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Leave(Guid id)
    {
        var result = await groupService.LeaveAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Returns all accounts shared in a group.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <returns>List of accounts.</returns>
    /// <response code="200">Accounts returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Group not found or user is not a member.</response>
    [HttpGet("{id:guid}/accounts")]
    [ProducesResponseType(typeof(List<AccountResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetAccounts(Guid id)
    {
        var result = await groupService.GetAccountsAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Adds an account to a group. Only the group owner can perform this action.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <param name="accountId">Identifier of the account to add.</param>
    /// <response code="204">Account added to the group successfully.</response>
    /// <response code="401">Requester is not authenticated.</response>
    /// <response code="403">Requester is not the owner of the group.</response>
    /// <response code="404">Group or account not found.</response>
    /// <response code="409">Account is already in the group.</response>
    [HttpPost("{id:guid}/accounts/{accountId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> AddAccount(Guid id, Guid accountId)
    {
        var result = await groupService.AddAccountAsync(id, GetCurrentUserId(), accountId);
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            ServiceStatus.Conflict => Conflict(new { message = "Account is already in this group." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Removes an account from a group. Only the group owner can perform this action.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <param name="accountId">Identifier of the account to remove.</param>
    /// <response code="204">Account removed from the group successfully.</response>
    /// <response code="401">Requester is not authenticated.</response>
    /// <response code="403">Requester is not the owner of the group.</response>
    /// <response code="404">Group or account not found in the group.</response>
    [HttpDelete("{id:guid}/accounts/{accountId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RemoveAccount(Guid id, Guid accountId)
    {
        var result = await groupService.RemoveAccountAsync(id, GetCurrentUserId(), accountId);
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
