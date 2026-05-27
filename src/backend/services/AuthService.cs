using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using SmartFinance.Models;
using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;
using SmartFinance.Services.Interfaces;

namespace SmartFinance.Services;

public class AuthService(SmartFinanceDbContext context, IConfiguration configuration) : IAuthService
{
    public async Task<ServiceResult<AuthResponse>> RegisterAsync(RegisterRequest request)
    {
        if (await context.Users.AnyAsync(u => u.Email == request.Email))
            return ServiceResult<AuthResponse>.Conflict();

        var user = new User
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            Email = request.Email,
            PasswordHash = BCrypt.Net.BCrypt.EnhancedHashPassword(request.Password),
            Birthday = request.Birthday
        };

        context.Users.Add(user);
        var refreshTokenValue = await CreateRefreshTokenAsync(user);
        await context.SaveChangesAsync();

        return ServiceResult<AuthResponse>.Ok(
            new AuthResponse(GenerateAccessToken(user), refreshTokenValue, MapUser(user)));
    }

    public async Task<ServiceResult<AuthResponse>> LoginAsync(LoginRequest request)
    {
        var user = await context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);

        if (user is null || !BCrypt.Net.BCrypt.EnhancedVerify(request.Password, user.PasswordHash))
            return ServiceResult<AuthResponse>.Unauthorized();

        var refreshTokenValue = await CreateRefreshTokenAsync(user);
        await context.SaveChangesAsync();

        return ServiceResult<AuthResponse>.Ok(
            new AuthResponse(GenerateAccessToken(user), refreshTokenValue, MapUser(user)));
    }

    public async Task<ServiceResult<AuthResponse>> RefreshAsync(string refreshToken)
    {
        var token = await context.RefreshTokens
            .Include(rt => rt.User)
            .FirstOrDefaultAsync(rt => rt.Token == refreshToken);

        if (token is null || token.IsRevoked || token.ExpiresAt <= DateTimeOffset.UtcNow)
            return ServiceResult<AuthResponse>.Unauthorized();

        token.IsRevoked = true;
        var newRefreshTokenValue = await CreateRefreshTokenAsync(token.User);
        await context.SaveChangesAsync();

        return ServiceResult<AuthResponse>.Ok(
            new AuthResponse(GenerateAccessToken(token.User), newRefreshTokenValue, MapUser(token.User)));
    }

    public async Task<ServiceResult> RevokeAsync(string refreshToken)
    {
        var token = await context.RefreshTokens
            .FirstOrDefaultAsync(rt => rt.Token == refreshToken);

        if (token is null) return ServiceResult.NotFound();

        token.IsRevoked = true;
        await context.SaveChangesAsync();

        return ServiceResult.Ok();
    }

    private async Task<string> CreateRefreshTokenAsync(User user)
    {
        var tokenValue = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        context.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = tokenValue,
            UserId = user.Id,
            ExpiresAt = DateTimeOffset.UtcNow.AddDays(30),
            CreatedAt = DateTimeOffset.UtcNow
        });
        return tokenValue;
    }

    private string GenerateAccessToken(User user)
    {
        var jwtSection = configuration.GetSection("Jwt");
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSection["Key"]!));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Name, user.Name)
        };

        var token = new JwtSecurityToken(
            issuer: jwtSection["Issuer"],
            audience: jwtSection["Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(double.Parse(jwtSection["ExpiresInMinutes"]!)),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static UserResponse MapUser(User user) =>
        new(user.Id, user.Name, user.Email, user.Birthday);
}
