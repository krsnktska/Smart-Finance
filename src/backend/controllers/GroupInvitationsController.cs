using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

public record InviteByEmailRequest(string Email);

/// <summary>
/// Manages group invitations — sending, accepting, and declining.
/// </summary>
[ApiController]
[Route("api")]
[Authorize]
[Produces("application/json")]
public class GroupInvitationsController(IGroupInvitationService invitationService) : ControllerBase
{
    /// <summary>
    /// Sends an invitation to a user by email to join a group. Only the group owner can invite.
    /// </summary>
    /// <param name="id">Group identifier.</param>
    /// <param name="request">Email of the user to invite.</param>
    /// <response code="201">Invitation sent successfully.</response>
    /// <response code="403">Requester is not the group owner.</response>
    /// <response code="404">Group not found or no user with that email exists.</response>
    /// <response code="409">User is already a member or has a pending invitation.</response>
    [HttpPost("groups/{id:guid}/invitations")]
    [ProducesResponseType(typeof(GroupInvitationResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Invite(Guid id, [FromBody] InviteByEmailRequest request)
    {
        var result = await invitationService.InviteByEmailAsync(id, GetCurrentUserId(), request.Email);
        return result.Status switch
        {
            ServiceStatus.Ok => CreatedAtAction(nameof(GetGroupInvitations), new { id }, result.Data),
            ServiceStatus.Forbidden => Forbid(),
            ServiceStatus.Conflict => Conflict(new { message = "User is already a member or has a pending invitation." }),
            ServiceStatus.NotFound => NotFound(new { message = "Group not found or no user with this email exists." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Returns all invitations for a group (owner only).
    /// </summary>
    /// <param name="id">Group identifier.</param>
    [HttpGet("groups/{id:guid}/invitations")]
    [ProducesResponseType(typeof(List<GroupInvitationResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetGroupInvitations(Guid id)
    {
        var result = await invitationService.GetGroupInvitationsAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Returns all pending invitations for the current user.
    /// </summary>
    [HttpGet("invitations")]
    [ProducesResponseType(typeof(List<GroupInvitationResponse>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMyInvitations()
    {
        var result = await invitationService.GetMyPendingAsync(GetCurrentUserId());
        return Ok(result.Data);
    }

    /// <summary>
    /// Accepts a group invitation. Only the invited user can accept.
    /// </summary>
    /// <param name="id">Invitation identifier.</param>
    /// <response code="204">Invitation accepted, user added to the group.</response>
    /// <response code="400">Invitation is no longer pending.</response>
    /// <response code="404">Invitation not found.</response>
    [HttpPost("invitations/{id:guid}/accept")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Accept(Guid id)
    {
        var result = await invitationService.AcceptAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.BadRequest => BadRequest(new { message = "Invitation is no longer pending." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Declines a group invitation. Only the invited user can decline.
    /// </summary>
    /// <param name="id">Invitation identifier.</param>
    /// <response code="204">Invitation declined.</response>
    /// <response code="400">Invitation is no longer pending.</response>
    /// <response code="404">Invitation not found.</response>
    [HttpPost("invitations/{id:guid}/decline")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Decline(Guid id)
    {
        var result = await invitationService.DeclineAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.BadRequest => BadRequest(new { message = "Invitation is no longer pending." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Cancels a pending group invitation. Only the user who sent the invitation can cancel it.
    /// </summary>
    /// <param name="groupId">Group identifier.</param>
    /// <param name="invitationId">Invitation identifier.</param>
    /// <response code="204">Invitation cancelled successfully.</response>
    /// <response code="400">Invitation is no longer pending.</response>
    /// <response code="403">Requester is not the sender of the invitation.</response>
    /// <response code="404">Invitation not found.</response>
    [HttpDelete("groups/{groupId:guid}/invitations/{invitationId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Cancel(Guid groupId, Guid invitationId)
    {
        var result = await invitationService.CancelAsync(invitationId, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            ServiceStatus.BadRequest => BadRequest(new { message = "Invitation is no longer pending." }),
            _ => StatusCode(500)
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
