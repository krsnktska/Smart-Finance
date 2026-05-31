using NpgsqlTypes;

namespace SmartFinance.Models;

public enum BankType
{
    [PgName("Monobank")]
    Monobank
}
