using Microsoft.EntityFrameworkCore;
using SmartFinance.Models;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class UserService(SmartFinanceDbContext context) : IUserService
{
    public async Task<ServiceResult<UserResponse>> GetByIdAsync(Guid userId)
    {
        var user = await context.Users.FindAsync(userId);

        if (user is null) return ServiceResult<UserResponse>.NotFound();

        return ServiceResult<UserResponse>.Ok(new UserResponse(user.Id, user.Name, user.Email, user.Birthday));
    }

    public async Task<ServiceResult<UserResponse>> UpdateAsync(Guid userId, UpdateUserRequest request)
    {
        var user = await context.Users.FindAsync(userId);

        if (user is null) return ServiceResult<UserResponse>.NotFound();

        if (request.Name is not null) user.Name = request.Name;
        if (request.Birthday.HasValue) user.Birthday = request.Birthday;

        await context.SaveChangesAsync();

        return ServiceResult<UserResponse>.Ok(new UserResponse(user.Id, user.Name, user.Email, user.Birthday));
    }

    public async Task<ServiceResult> ChangePasswordAsync(Guid userId, ChangePasswordRequest request)
    {
        var user = await context.Users.FindAsync(userId);

        if (user is null) return ServiceResult.NotFound();

        if (!BCrypt.Net.BCrypt.EnhancedVerify(request.CurrentPassword, user.PasswordHash))
            return ServiceResult.Unauthorized();

        user.PasswordHash = BCrypt.Net.BCrypt.EnhancedHashPassword(request.NewPassword);

        var activeTokens = await context.RefreshTokens
            .Where(rt => rt.UserId == userId && !rt.IsRevoked)
            .ToListAsync();

        foreach (var token in activeTokens)
            token.IsRevoked = true;

        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }
}
