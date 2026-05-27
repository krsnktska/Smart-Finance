namespace SmartFinance.Models.Responses;

public record AccountSummaryResponse(
    decimal TotalIncome,
    decimal TotalExpense,
    decimal Balance,
    DateTimeOffset? From,
    DateTimeOffset? To);
