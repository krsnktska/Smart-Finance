using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Handles physical and electronic receipt processing: OCR scanning and web scraping.
/// </summary>
[ApiController]
[Route("api/receipts")]
[Authorize]
[Produces("application/json")]
public class ReceiptsController(IReceiptService receiptService) : ControllerBase
{
    /// <summary>
    /// Scans a receipt photo using OCR, extracts items, and creates a transaction with AI-assigned categories.
    /// </summary>
    /// <param name="image">Receipt image file (JPEG/PNG).</param>
    /// <param name="accountId">Target account identifier.</param>
    /// <returns>Created transaction with parsed receipt items.</returns>
    /// <response code="201">Receipt scanned and transaction created.</response>
    /// <response code="400">Image is invalid or OCR failed.</response>
    /// <response code="403">Account does not belong to the user.</response>
    [HttpPost("scan")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ReceiptScanResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> ScanPhoto(IFormFile image, [FromQuery] Guid accountId)
    {
        var result = await receiptService.ScanPhotoAsync(image, accountId, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => CreatedAtAction(nameof(ScanPhoto), result.Data),
            ServiceStatus.Forbidden => Forbid(),
            _ => BadRequest()
        };
    }

    /// <summary>
    /// Scrapes an electronic receipt from a URL and creates a transaction.
    /// </summary>
    /// <param name="request">Receipt URL and target account.</param>
    /// <returns>Created transaction with scraped receipt items.</returns>
    /// <response code="201">Receipt scraped and transaction created.</response>
    /// <response code="400">URL is invalid or scraping failed.</response>
    /// <response code="403">Account does not belong to the user.</response>
    [HttpPost("scrape")]
    [ProducesResponseType(typeof(ReceiptScanResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> ScrapeUrl([FromBody] ScrapeReceiptRequest request)
    {
        var result = await receiptService.ScrapeUrlAsync(request, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => CreatedAtAction(nameof(ScrapeUrl), result.Data),
            ServiceStatus.Forbidden => Forbid(),
            _ => BadRequest()
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
