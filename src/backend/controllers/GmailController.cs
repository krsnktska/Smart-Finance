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
        if (!Guid.TryParse(state, out var userId))
            return Content(GetFailureHtml("Invalid state parameter."), "text/html", System.Text.Encoding.UTF8);

        var result = await gmailService.HandleCallbackAsync(code, userId, accountId);
        if (result.Status == ServiceStatus.Ok && result.Data != null)
        {
            return Content(GetSuccessHtml(result.Data.GmailAddress), "text/html", System.Text.Encoding.UTF8);
        }

        return Content(GetFailureHtml("Failed to complete Gmail authorization."), "text/html", System.Text.Encoding.UTF8);
    }

    private static string GetSuccessHtml(string email)
    {
        return $$"""
        <!DOCTYPE html>
        <html lang="uk">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>SmartFinance - Gmail Підключено</title>
            <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet">
            <style>
                :root {
                    --bg-color: #0f172a;
                    --card-bg: #1e293b;
                    --primary: #10b981;
                    --primary-hover: #059669;
                    --text-main: #f8fafc;
                    --text-muted: #94a3b8;
                }
                body {
                    background-color: var(--bg-color);
                    color: var(--text-main);
                    font-family: 'Outfit', sans-serif;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    margin: 0;
                    padding: 20px;
                    box-sizing: border-box;
                    overflow: hidden;
                }
                .container {
                    background-color: var(--card-bg);
                    border-radius: 24px;
                    padding: 40px;
                    text-align: center;
                    box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.3), 0 8px 10px -6px rgb(0 0 0 / 0.3);
                    max-width: 440px;
                    width: 100%;
                    border: 1px solid rgba(255, 255, 255, 0.05);
                    transform: scale(0.9);
                    opacity: 0;
                    animation: slideUp 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards;
                }
                @keyframes slideUp {
                    to {
                        transform: scale(1);
                        opacity: 1;
                    }
                }
                .icon-container {
                    width: 80px;
                    height: 80px;
                    background: rgba(16, 185, 129, 0.1);
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 24px;
                    position: relative;
                }
                .checkmark {
                    width: 40px;
                    height: 40px;
                    stroke-width: 4;
                    stroke: var(--primary);
                    stroke-linecap: round;
                    stroke-linejoin: round;
                    fill: none;
                    stroke-dasharray: 48;
                    stroke-dashoffset: 48;
                    animation: stroke 0.6s cubic-bezier(0.65, 0, 0.45, 1) 0.3s forwards;
                }
                @keyframes stroke {
                    to {
                        stroke-dashoffset: 0;
                    }
                }
                h1 {
                    font-size: 26px;
                    font-weight: 800;
                    margin: 0 0 12px;
                    letter-spacing: -0.5px;
                    background: linear-gradient(135deg, #f8fafc 0%, #cbd5e1 100%);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                }
                p {
                    color: var(--text-muted);
                    font-size: 15px;
                    line-height: 1.6;
                    margin: 0 0 24px;
                }
                .email-badge {
                    background: rgba(16, 185, 129, 0.06);
                    border: 1px solid rgba(16, 185, 129, 0.15);
                    padding: 8px 18px;
                    border-radius: 9999px;
                    display: inline-block;
                    font-size: 14px;
                    font-weight: 600;
                    color: var(--primary);
                    margin-bottom: 32px;
                    word-break: break-all;
                }
                .btn {
                    background-color: var(--primary);
                    color: white;
                    border: none;
                    padding: 14px 28px;
                    border-radius: 14px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                    width: 100%;
                    transition: all 0.2s ease;
                    box-shadow: 0 10px 15px -3px rgba(16, 185, 129, 0.3);
                    text-decoration: none;
                    display: block;
                    box-sizing: border-box;
                }
                .btn:hover {
                    background-color: var(--primary-hover);
                    transform: translateY(-2px);
                    box-shadow: 0 12px 20px -3px rgba(16, 185, 129, 0.4);
                }
                .btn:active {
                    transform: translateY(0);
                }
                .footer {
                    margin-top: 24px;
                    font-size: 13px;
                    color: #64748b;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon-container">
                    <svg class="checkmark" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 52">
                        <path d="M14 27.2l7.1 7.2 16.7-16.8"/>
                    </svg>
                </div>
                <h1>Пошту підключено!</h1>
                <p>SmartFinance успішно зв'язав ваш Google-акаунт для автоматичного сканування електронних чеків.</p>
                <div class="email-badge">{{email}}</div>
                <a href="smartfinance://gmail-callback?success=true" class="btn" id="redirectBtn">Повернутися в додаток</a>
                <div class="footer">
                    Якщо перенаправлення не відбулося автоматично, натисніть кнопку вище або просто закрийте це вікно.
                </div>
            </div>
            <script>
                // Спроба автоматично відкрити додаток через 1.2 секунди
                setTimeout(function() {
                    window.location.href = "smartfinance://gmail-callback?success=true";
                }, 1200);
            </script>
        </body>
        </html>
        """;
    }

    private static string GetFailureHtml(string error)
    {
        return $$"""
        <!DOCTYPE html>
        <html lang="uk">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>SmartFinance - Помилка підключення</title>
            <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet">
            <style>
                :root {
                    --bg-color: #0f172a;
                    --card-bg: #1e293b;
                    --error: #ef4444;
                    --error-hover: #dc2626;
                    --text-main: #f8fafc;
                    --text-muted: #94a3b8;
                }
                body {
                    background-color: var(--bg-color);
                    color: var(--text-main);
                    font-family: 'Outfit', sans-serif;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    margin: 0;
                    padding: 20px;
                    box-sizing: border-box;
                    overflow: hidden;
                }
                .container {
                    background-color: var(--card-bg);
                    border-radius: 24px;
                    padding: 40px;
                    text-align: center;
                    box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.3), 0 8px 10px -6px rgb(0 0 0 / 0.3);
                    max-width: 440px;
                    width: 100%;
                    border: 1px solid rgba(255, 255, 255, 0.05);
                    transform: scale(0.9);
                    opacity: 0;
                    animation: slideUp 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards;
                }
                @keyframes slideUp {
                    to {
                        transform: scale(1);
                        opacity: 1;
                    }
                }
                .icon-container {
                    width: 80px;
                    height: 80px;
                    background: rgba(239, 68, 68, 0.1);
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 24px;
                    position: relative;
                }
                .cross {
                    width: 40px;
                    height: 40px;
                    stroke-width: 4;
                    stroke: var(--error);
                    stroke-linecap: round;
                    stroke-linejoin: round;
                    fill: none;
                    stroke-dasharray: 48;
                    stroke-dashoffset: 48;
                    animation: stroke 0.5s cubic-bezier(0.65, 0, 0.45, 1) 0.2s forwards;
                }
                @keyframes stroke {
                    to {
                        stroke-dashoffset: 0;
                    }
                }
                h1 {
                    font-size: 26px;
                    font-weight: 800;
                    margin: 0 0 12px;
                    letter-spacing: -0.5px;
                    background: linear-gradient(135deg, #f8fafc 0%, #cbd5e1 100%);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                }
                p {
                    color: var(--text-muted);
                    font-size: 15px;
                    line-height: 1.6;
                    margin: 0 0 24px;
                }
                .error-badge {
                    background: rgba(239, 68, 68, 0.06);
                    border: 1px solid rgba(239, 68, 68, 0.15);
                    padding: 8px 18px;
                    border-radius: 12px;
                    display: inline-block;
                    font-size: 14px;
                    font-weight: 600;
                    color: var(--error);
                    margin-bottom: 32px;
                    word-break: break-all;
                }
                .btn {
                    background-color: var(--error);
                    color: white;
                    border: none;
                    padding: 14px 28px;
                    border-radius: 14px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                    width: 100%;
                    transition: all 0.2s ease;
                    box-shadow: 0 10px 15px -3px rgba(239, 68, 68, 0.3);
                    text-decoration: none;
                    display: block;
                    box-sizing: border-box;
                }
                .btn:hover {
                    background-color: var(--error-hover);
                    transform: translateY(-2px);
                    box-shadow: 0 12px 20px -3px rgba(239, 68, 68, 0.4);
                }
                .btn:active {
                    transform: translateY(0);
                }
                .footer {
                    margin-top: 24px;
                    font-size: 13px;
                    color: #64748b;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon-container">
                    <svg class="cross" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 52">
                        <path d="M16 16l20 20M36 16L16 36"/>
                    </svg>
                </div>
                <h1>Помилка авторизації</h1>
                <p>Не вдалося успішно зв'язати Google-акаунт із вашим профілем фінансів.</p>
                <div class="error-badge">{{error}}</div>
                <a href="smartfinance://gmail-callback?success=false" class="btn" id="redirectBtn">Повернутися в додаток</a>
                <div class="footer">
                    Будь ласка, спробуйте ще раз або закрийте вікно та перевірте підключення до мережі.
                </div>
            </div>
            <script>
                // Спроба автоматично повернути до додатка через 2 секунди
                setTimeout(function() {
                    window.location.href = "smartfinance://gmail-callback?success=false";
                }, 2000);
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
