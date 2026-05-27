using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Manages financial accounts belonging to the authenticated user.
/// </summary>
[ApiController]
[Route("api/accounts")]
[Authorize]
[Produces("application/json")]
public class AccountsController(IAccountService accountService, IStatisticsService statisticsService) : ControllerBase
{
    /// <summary>
    /// Returns all accounts of the authenticated user.
    /// </summary>
    /// <returns>List of accounts.</returns>
    /// <response code="200">Accounts returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    [HttpGet]
    [ProducesResponseType(typeof(List<AccountResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetAll() =>
        Ok(await accountService.GetAllAsync(GetCurrentUserId()));

    /// <summary>
    /// Returns a single account by its identifier.
    /// </summary>
    /// <param name="id">Account identifier.</param>
    /// <returns>Account data.</returns>
    /// <response code="200">Account returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Account not found or does not belong to the user.</response>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(AccountResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(Guid id)
    {
        var result = await accountService.GetByIdAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Creates a new account for the authenticated user.
    /// </summary>
    /// <param name="request">Account creation data.</param>
    /// <returns>Newly created account.</returns>
    /// <response code="201">Account created successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    [HttpPost]
    [ProducesResponseType(typeof(AccountResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Create([FromBody] CreateAccountRequest request)
    {
        var account = await accountService.CreateAsync(GetCurrentUserId(), request);
        return CreatedAtAction(nameof(GetById), new { id = account.Id }, account);
    }

    /// <summary>
    /// Updates an existing account.
    /// </summary>
    /// <param name="id">Account identifier.</param>
    /// <param name="request">Fields to update (null values are ignored).</param>
    /// <returns>Updated account data.</returns>
    /// <response code="200">Account updated successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Account not found or does not belong to the user.</response>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(AccountResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateAccountRequest request)
    {
        var result = await accountService.UpdateAsync(id, GetCurrentUserId(), request);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Deletes an account and all its transactions.
    /// </summary>
    /// <param name="id">Account identifier.</param>
    /// <response code="204">Account deleted successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Account not found or does not belong to the user.</response>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id)
    {
        var result = await accountService.DeleteAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Returns income/expense summary for the account over an optional date range.
    /// </summary>
    /// <param name="id">Account identifier.</param>
    /// <param name="from">Optional start date (inclusive).</param>
    /// <param name="to">Optional end date (inclusive).</param>
    /// <returns>Totals for income, expense and net balance.</returns>
    /// <response code="200">Summary returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Account not found or does not belong to the user.</response>
    [HttpGet("{id:guid}/summary")]
    [ProducesResponseType(typeof(AccountSummaryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetSummary(
        Guid id,
        [FromQuery] DateTimeOffset? from,
        [FromQuery] DateTimeOffset? to)
    {
        var result = await statisticsService.GetSummaryAsync(id, GetCurrentUserId(), from, to);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Returns expense totals grouped by category for the account over an optional date range.
    /// </summary>
    /// <param name="id">Account identifier.</param>
    /// <param name="from">Optional start date (inclusive).</param>
    /// <param name="to">Optional end date (inclusive).</param>
    /// <returns>List of category spending breakdowns.</returns>
    /// <response code="200">Category breakdown returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Account not found or does not belong to the user.</response>
    [HttpGet("{id:guid}/by-category")]
    [ProducesResponseType(typeof(List<CategorySpendingResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetByCategory(
        Guid id,
        [FromQuery] DateTimeOffset? from,
        [FromQuery] DateTimeOffset? to)
    {
        var result = await statisticsService.GetByCategoryAsync(id, GetCurrentUserId(), from, to);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
