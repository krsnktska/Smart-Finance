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
    public async Task<IActionResult> OAuthCallback([FromQuery] string code, [FromQuery] Guid accountId, [FromQuery] string state)
    {
        string redirectUrl;

        if (!Guid.TryParse(state, out var userId))
        {
            redirectUrl = "smartfinance://gmail-callback?success=false&error=InvalidState";
        }
        else
        {
            var result = await gmailService.HandleCallbackAsync(code, userId, accountId);
            if (result.Status == ServiceStatus.Ok && result.Data != null)
            {
                redirectUrl = "smartfinance://gmail-callback?success=true";
            }
            else
            {
                redirectUrl = "smartfinance://gmail-callback?success=false&error=AuthFailed";
            }
        }

        return Content(GetRedirectHtml(redirectUrl), "text/html", System.Text.Encoding.UTF8);
    }

    private static string GetRedirectHtml(string url)
    {
        return $$"""
        <!DOCTYPE html>
        <html lang="uk">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>SmartFinance</title>
            <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600&display=swap" rel="stylesheet">
            <style>
                body {
                    background-color: #0f172a;
                    color: #f8fafc;
                    font-family: 'Outfit', sans-serif;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    margin: 0;
                    padding: 20px;
                    box-sizing: border-box;
                }
                .container {
                    text-align: center;
                }
                .spinner {
                    width: 50px;
                    height: 50px;
                    border: 4px solid rgba(255, 255, 255, 0.1);
                    border-top: 4px solid #10b981;
                    border-radius: 50%;
                    animation: spin 1s linear infinite;
                    margin: 0 auto 20px;
                }
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
                p {
                    color: #94a3b8;
                    font-size: 16px;
                    font-weight: 600;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="spinner"></div>
                <p>Повернення до SmartFinance...</p>
            </div>
            <script>
                function doRedirect() {
                    window.location.replace("{{url}}");
                    setTimeout(function() {
                        window.location.href = "{{url}}";
                    }, 250);
                }
                window.onload = doRedirect;
            </script>
        </body>
        </html>
        """;
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
