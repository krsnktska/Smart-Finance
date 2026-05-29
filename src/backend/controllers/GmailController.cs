using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Gmail integration for automatic electronic receipt detection.
/// </summary>
[ApiController]
[Route("api/gmail")]
[Authorize]
[Produces("application/json")]
public class GmailController(IGmailIntegrationService gmailService) : ControllerBase
{
    /// <summary>
    /// Returns the Google OAuth2 authorization URL. Redirect the user to this URL to connect Gmail.
    /// </summary>
    [HttpGet("auth")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public IActionResult GetAuthUrl()
    {
        var url = gmailService.GetAuthorizationUrl(GetCurrentUserId());
        return Ok(new { authUrl = url });
    }

    /// <summary>
    /// OAuth2 callback endpoint. Called by Google after the user authorizes access.
    /// </summary>
    /// <param name="code">Authorization code from Google.</param>
    /// <param name="accountId">SmartFinance account to link receipts to.</param>
    /// <param name="state">User ID passed through OAuth state parameter.</param>
    [HttpGet("callback")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(GmailIntegrationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> OAuthCallback([FromQuery] string code, [FromQuery] Guid accountId, [FromQuery] string state)
    {
        if (!Guid.TryParse(state, out var userId))
            return BadRequest("Invalid state parameter.");

        var result = await gmailService.HandleCallbackAsync(code, userId, accountId);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            _ => BadRequest("Failed to complete Gmail authorization.")
        };
    }

    /// <summary>
    /// Returns the current Gmail integration status for the user.
    /// </summary>
    [HttpGet("status")]
    [ProducesResponseType(typeof(GmailIntegrationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetStatus()
    {
        var status = await gmailService.GetStatusAsync(GetCurrentUserId());
        if (status is null) return NotFound();
        return Ok(status);
    }

    /// <summary>
    /// Scans the connected Gmail inbox for electronic receipts and imports them as transactions.
    /// </summary>
    /// <param name="accountId">Target account for imported transactions.</param>
    /// <returns>List of created transactions from detected receipts.</returns>
    [HttpPost("scan")]
    [ProducesResponseType(typeof(List<ReceiptScanResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ScanInbox([FromQuery] Guid accountId)
    {
        var result = await gmailService.ScanInboxAsync(GetCurrentUserId(), accountId);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound("Gmail integration not found. Please connect Gmail first."),
            ServiceStatus.Forbidden => Forbid(),
            _ => BadRequest("Failed to scan inbox.")
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
