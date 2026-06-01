namespace SmartFinance.Models.Responses;

public record MonobankAccountResponse(
    string Id,
    string Type,
    string Currency,
    decimal Balance,
    decimal CreditLimit,
    string? MaskedPan,
    string? Iban
);
