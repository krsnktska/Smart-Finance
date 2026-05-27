using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Manages financial transactions linked to the user's accounts.
/// </summary>
[ApiController]
[Route("api/transactions")]
[Authorize]
[Produces("application/json")]
public class TransactionsController(ITransactionService transactionService) : ControllerBase
{
    /// <summary>
    /// Returns all transactions for a given account.
    /// </summary>
    /// <param name="accountId">Account identifier to filter by.</param>
    /// <returns>List of transactions.</returns>
    /// <response code="200">Transactions returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="403">Account does not belong to the authenticated user.</response>
    [HttpGet]
    [ProducesResponseType(typeof(List<TransactionResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetAll([FromQuery] Guid accountId)
    {
        var result = await transactionService.GetAllAsync(accountId, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Returns a single transaction by its identifier.
    /// </summary>
    /// <param name="id">Transaction identifier.</param>
    /// <returns>Transaction data.</returns>
    /// <response code="200">Transaction returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Transaction not found or access is denied.</response>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(TransactionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(Guid id)
    {
        var result = await transactionService.GetByIdAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Creates a new transaction for the specified account.
    /// </summary>
    /// <param name="request">Transaction data.</param>
    /// <returns>Newly created transaction.</returns>
    /// <response code="201">Transaction created successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="403">Account does not belong to the authenticated user.</response>
    [HttpPost]
    [ProducesResponseType(typeof(TransactionResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> Create([FromBody] CreateTransactionRequest request)
    {
        var result = await transactionService.CreateAsync(request, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => CreatedAtAction(nameof(GetById), new { id = result.Data!.Id }, result.Data),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Updates an existing transaction.
    /// </summary>
    /// <param name="id">Transaction identifier.</param>
    /// <param name="request">Fields to update (null values are ignored).</param>
    /// <returns>Updated transaction data.</returns>
    /// <response code="200">Transaction updated successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Transaction not found or access is denied.</response>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(TransactionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateTransactionRequest request)
    {
        var result = await transactionService.UpdateAsync(id, GetCurrentUserId(), request);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Deletes a transaction by its identifier.
    /// </summary>
    /// <param name="id">Transaction identifier.</param>
    /// <response code="204">Transaction deleted successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Transaction not found or access is denied.</response>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id)
    {
        var result = await transactionService.DeleteAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
