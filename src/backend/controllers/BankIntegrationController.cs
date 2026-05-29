using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Manages Monobank integration for automatic transaction synchronization.
/// </summary>
[ApiController]
[Route("api/bank")]
[Authorize]
[Produces("application/json")]
public class BankIntegrationController(IMonobankService monobankService) : ControllerBase
{
    /// <summary>Returns all Monobank integrations for the current user.</summary>
    [HttpGet("monobank")]
    [ProducesResponseType(typeof(List<BankIntegrationResponse>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMonobankIntegrations()
    {
        var result = await monobankService.GetIntegrationsAsync(GetCurrentUserId());
        return Ok(result.Data);
    }

    /// <summary>
    /// Connects a Monobank account using a personal API token.
    /// Get your token at https://api.monobank.ua
    /// </summary>
    /// <param name="request">Monobank token and target account.</param>
    [HttpPost("monobank/setup")]
    [ProducesResponseType(typeof(BankIntegrationResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> SetupMonobank([FromBody] SetupBankIntegrationRequest request)
    {
        var result = await monobankService.SetupAsync(request, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => CreatedAtAction(nameof(GetMonobankIntegrations), result.Data),
            ServiceStatus.Forbidden => Forbid(),
            _ => BadRequest()
        };
    }

    /// <summary>
    /// Syncs Monobank transactions for a given date range into the linked account.
    /// </summary>
    /// <param name="request">Integration ID, from/to dates.</param>
    [HttpPost("monobank/sync")]
    [ProducesResponseType(typeof(List<TransactionResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SyncMonobank([FromBody] SyncBankRequest request)
    {
        var result = await monobankService.SyncAsync(request, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => BadRequest()
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
