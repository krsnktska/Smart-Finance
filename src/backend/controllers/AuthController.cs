using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Handles user authentication: registration, login, token refresh and revocation.
/// </summary>
[ApiController]
[Route("api/auth")]
[Produces("application/json")]
public class AuthController(IAuthService authService) : ControllerBase
{
    /// <summary>
    /// Registers a new user account.
    /// </summary>
    /// <param name="request">User registration data.</param>
    /// <returns>JWT access token, refresh token and user info.</returns>
    /// <response code="201">User created successfully.</response>
    /// <response code="409">Email is already in use.</response>
    [HttpPost("register")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var result = await authService.RegisterAsync(request);
        return result.Status switch
        {
            ServiceStatus.Ok => CreatedAtAction(nameof(Register), result.Data),
            ServiceStatus.Conflict => Conflict(new { message = "Email is already in use." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Authenticates an existing user and returns a JWT access token and refresh token.
    /// </summary>
    /// <param name="request">User credentials.</param>
    /// <returns>JWT access token, refresh token and user info.</returns>
    /// <response code="200">Authentication successful.</response>
    /// <response code="401">Invalid email or password.</response>
    [HttpPost("login")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var result = await authService.LoginAsync(request);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.Unauthorized => Unauthorized(new { message = "Invalid email or password." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Issues a new access token and refresh token using a valid refresh token (token rotation).
    /// </summary>
    /// <param name="request">Current refresh token.</param>
    /// <returns>New JWT access token and refresh token.</returns>
    /// <response code="200">Tokens refreshed successfully.</response>
    /// <response code="401">Refresh token is invalid, expired or revoked.</response>
    [HttpPost("refresh")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Refresh([FromBody] RefreshTokenRequest request)
    {
        var result = await authService.RefreshAsync(request.RefreshToken);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.Unauthorized => Unauthorized(new { message = "Invalid or expired refresh token." }),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Revokes a refresh token (logout).
    /// </summary>
    /// <param name="request">Refresh token to revoke.</param>
    /// <response code="204">Token revoked successfully.</response>
    /// <response code="404">Token not found.</response>
    [HttpPost("revoke")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Revoke([FromBody] RefreshTokenRequest request)
    {
        var result = await authService.RevokeAsync(request.RefreshToken);
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }
}
