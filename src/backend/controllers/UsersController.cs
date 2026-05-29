using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Manages the authenticated user's profile.
/// </summary>
[ApiController]
[Route("api/users")]
[Authorize]
[Produces("application/json")]
public class UsersController(IUserService userService) : ControllerBase
{
    /// <summary>
    /// Finds a user by email address. Used to get a userId before adding them to a group.
    /// </summary>
    /// <param name="email">Email address to search for.</param>
    /// <returns>Basic user info (id, name, email).</returns>
    /// <response code="200">User found.</response>
    /// <response code="404">No user with that email exists.</response>
    [HttpGet("search")]
    [ProducesResponseType(typeof(UserResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> FindByEmail([FromQuery] string email)
    {
        var result = await userService.FindByEmailAsync(email);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Returns the currently authenticated user's profile.
    /// </summary>
    /// <returns>User profile data.</returns>
    /// <response code="200">User profile returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">User not found.</response>
    [HttpGet("me")]
    [ProducesResponseType(typeof(UserResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetMe()
    {
        var result = await userService.GetByIdAsync(GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Updates the currently authenticated user's profile.
    /// </summary>
    /// <param name="request">Fields to update (null values are ignored).</param>
    /// <returns>Updated user profile.</returns>
    /// <response code="200">User profile updated successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">User not found.</response>
    [HttpPut("me")]
    [ProducesResponseType(typeof(UserResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateMe([FromBody] UpdateUserRequest request)
    {
        var result = await userService.UpdateAsync(GetCurrentUserId(), request);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Changes the authenticated user's password. Revokes all active refresh tokens.
    /// </summary>
    /// <param name="request">Current and new password.</param>
    /// <response code="204">Password changed successfully.</response>
    /// <response code="401">Current password is incorrect or user is not authenticated.</response>
    /// <response code="404">User not found.</response>
    [HttpPatch("me/password")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var result = await userService.ChangePasswordAsync(GetCurrentUserId(), request);
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Unauthorized => Unauthorized(new { message = "Current password is incorrect." }),
            _ => StatusCode(500)
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
