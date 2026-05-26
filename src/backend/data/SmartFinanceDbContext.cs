using Microsoft.EntityFrameworkCore;

namespace SmartFinance.Models;

public class SmartFinanceDbContext(DbContextOptions<SmartFinanceDbContext> options) : DbContext(options)
{
    public DbSet<User> Users { get; set; }
    public DbSet<Group> Groups { get; set; }
    public DbSet<Account> Accounts { get; set; }
    public DbSet<Category> Categories { get; set; }
    public DbSet<Transaction> Transactions { get; set; }
    public DbSet<UserGroup> UserGroups { get; set; }
    public DbSet<TransactionCategory> TransactionCategories { get; set; }
    public DbSet<AccountGroup> AccountGroups { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasPostgresEnum<TransactionType>();
        modelBuilder.HasPostgresEnum<SpecialType>();

        modelBuilder.Entity<UserGroup>()
            .HasKey(ug => new { ug.UserId, ug.GroupId });

        modelBuilder.Entity<TransactionCategory>()
            .HasKey(tc => new { tc.TransactionId, tc.CategoryId });

        modelBuilder.Entity<AccountGroup>()
            .HasKey(ag => new { ag.AccountId, ag.GroupId });

        modelBuilder.Entity<User>()
            .HasIndex(u => u.Email)
            .IsUnique();
    }
}
