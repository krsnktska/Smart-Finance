using Microsoft.EntityFrameworkCore;

namespace SmartFinance.Models;

public class SmartFinanceDbContext(DbContextOptions<SmartFinanceDbContext> options) : DbContext(options)
{
    public DbSet<User> Users { get; set; } = null!;
    public DbSet<Group> Groups { get; set; } = null!;
    public DbSet<Account> Accounts { get; set; } = null!;
    public DbSet<Category> Categories { get; set; } = null!;
    public DbSet<Transaction> Transactions { get; set; } = null!;
    public DbSet<UserGroup> UserGroups { get; set; } = null!;
    public DbSet<TransactionCategory> TransactionCategories { get; set; } = null!;
    public DbSet<AccountGroup> AccountGroups { get; set; } = null!;
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;
    public DbSet<ReceiptItem> ReceiptItems { get; set; } = null!;
    public DbSet<GmailToken> GmailTokens { get; set; } = null!;
    public DbSet<BankIntegration> BankIntegrations { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasPostgresEnum<TransactionType>();
        modelBuilder.HasPostgresEnum<SpecialType>();
        modelBuilder.HasPostgresEnum<BankType>();

        modelBuilder.Entity<UserGroup>()
            .HasKey(ug => new { ug.UserId, ug.GroupId });

        modelBuilder.Entity<TransactionCategory>()
            .HasKey(tc => new { tc.TransactionId, tc.CategoryId });

        modelBuilder.Entity<AccountGroup>()
            .HasKey(ag => new { ag.AccountId, ag.GroupId });

        modelBuilder.Entity<User>()
            .HasIndex(u => u.Email)
            .IsUnique();

        modelBuilder.Entity<RefreshToken>()
            .HasIndex(rt => rt.Token)
            .IsUnique();

        modelBuilder.Entity<GmailToken>()
            .HasIndex(gt => gt.UserId)
            .IsUnique();

        modelBuilder.Entity<BankIntegration>()
            .HasIndex(bi => new { bi.UserId, bi.BankType, bi.BankAccountId });
    }
}
