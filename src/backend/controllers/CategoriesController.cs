using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Controllers;

/// <summary>
/// Manages transaction categories (global and user-specific).
/// </summary>
[ApiController]
[Route("api/categories")]
[Authorize]
[Produces("application/json")]
public class CategoriesController(ICategoryService categoryService) : ControllerBase
{
    /// <summary>
    /// Returns all global categories and those belonging to the authenticated user.
    /// </summary>
    /// <returns>List of categories.</returns>
    /// <response code="200">Categories returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    [HttpGet]
    [ProducesResponseType(typeof(List<CategoryResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetAll() =>
        Ok(await categoryService.GetAllAsync(GetCurrentUserId()));

    /// <summary>
    /// Returns a single category by its identifier.
    /// </summary>
    /// <param name="id">Category identifier.</param>
    /// <returns>Category data.</returns>
    /// <response code="200">Category returned successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="404">Category not found or access is denied.</response>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(CategoryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(Guid id)
    {
        var result = await categoryService.GetByIdAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Creates a new category for the authenticated user.
    /// </summary>
    /// <param name="request">Category creation data.</param>
    /// <returns>Newly created category.</returns>
    /// <response code="201">Category created successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    [HttpPost]
    [ProducesResponseType(typeof(CategoryResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Create([FromBody] CreateCategoryRequest request)
    {
        var category = await categoryService.CreateAsync(GetCurrentUserId(), request);
        return CreatedAtAction(nameof(GetById), new { id = category.Id }, category);
    }

    /// <summary>
    /// Updates a user-owned category.
    /// </summary>
    /// <param name="id">Category identifier.</param>
    /// <param name="request">Fields to update (null values are ignored).</param>
    /// <returns>Updated category data.</returns>
    /// <response code="200">Category updated successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="403">Cannot modify a global category.</response>
    /// <response code="404">Category not found.</response>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(CategoryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateCategoryRequest request)
    {
        var result = await categoryService.UpdateAsync(id, GetCurrentUserId(), request);
        return result.Status switch
        {
            ServiceStatus.Ok => Ok(result.Data),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    /// <summary>
    /// Deletes a user-owned category.
    /// </summary>
    /// <param name="id">Category identifier.</param>
    /// <response code="204">Category deleted successfully.</response>
    /// <response code="401">User is not authenticated.</response>
    /// <response code="403">Cannot delete a global category.</response>
    /// <response code="404">Category not found.</response>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id)
    {
        var result = await categoryService.DeleteAsync(id, GetCurrentUserId());
        return result.Status switch
        {
            ServiceStatus.Ok => NoContent(),
            ServiceStatus.NotFound => NotFound(),
            ServiceStatus.Forbidden => Forbid(),
            _ => StatusCode(500)
        };
    }

    private Guid GetCurrentUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
