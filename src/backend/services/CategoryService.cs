using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class CategoryService(SmartFinanceDbContext context) : ICategoryService
{
    public async Task<List<CategoryResponse>> GetAllAsync(Guid userId) =>
        await context.Categories
            .Where(c => c.UserId == null || c.UserId == userId)
            .Select(c => new CategoryResponse(c.Id, c.Name, c.Color, c.Emoji, c.UserId))
            .ToListAsync();

    public async Task<ServiceResult<CategoryResponse>> GetByIdAsync(Guid id, Guid userId)
    {
        var category = await context.Categories
            .FirstOrDefaultAsync(c => c.Id == id && (c.UserId == null || c.UserId == userId));

        if (category is null) return ServiceResult<CategoryResponse>.NotFound();

        return ServiceResult<CategoryResponse>.Ok(
            new CategoryResponse(category.Id, category.Name, category.Color, category.Emoji, category.UserId));
    }

    public async Task<CategoryResponse> CreateAsync(Guid userId, CreateCategoryRequest request)
    {
        var category = new Category
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            Color = request.Color,
            Emoji = request.Emoji,
            UserId = userId
        };

        context.Categories.Add(category);
        await context.SaveChangesAsync();

        return new CategoryResponse(category.Id, category.Name, category.Color, category.Emoji, category.UserId);
    }

    public async Task<ServiceResult<CategoryResponse>> UpdateAsync(Guid id, Guid userId, UpdateCategoryRequest request)
    {
        var category = await context.Categories.FindAsync(id);

        if (category is null) return ServiceResult<CategoryResponse>.NotFound();
        if (category.UserId != userId) return ServiceResult<CategoryResponse>.Forbidden();

        if (request.Name is not null) category.Name = request.Name;
        if (request.Color is not null) category.Color = request.Color;
        if (request.Emoji is not null) category.Emoji = request.Emoji;

        await context.SaveChangesAsync();

        return ServiceResult<CategoryResponse>.Ok(
            new CategoryResponse(category.Id, category.Name, category.Color, category.Emoji, category.UserId));
    }

    public async Task<ServiceResult> DeleteAsync(Guid id, Guid userId)
    {
        var category = await context.Categories.FindAsync(id);

        if (category is null) return ServiceResult.NotFound();
        if (category.UserId != userId) return ServiceResult.Forbidden();

        context.Categories.Remove(category);
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }
}
