namespace SmartFinance.Services;

public enum ServiceStatus { Ok, NotFound, Forbidden, Conflict, Unauthorized, BadRequest }

public record ServiceResult(ServiceStatus Status)
{
    public bool IsOk => Status == ServiceStatus.Ok;

    public static ServiceResult Ok() => new(ServiceStatus.Ok);
    public static ServiceResult NotFound() => new(ServiceStatus.NotFound);
    public static ServiceResult Forbidden() => new(ServiceStatus.Forbidden);
    public static ServiceResult Conflict() => new(ServiceStatus.Conflict);
    public static ServiceResult Unauthorized() => new(ServiceStatus.Unauthorized);
    public static ServiceResult BadRequest() => new(ServiceStatus.BadRequest);
}

public record ServiceResult<T>(ServiceStatus Status, T? Data) where T : class
{
    public bool IsOk => Status == ServiceStatus.Ok;

    public static ServiceResult<T> Ok(T data) => new(ServiceStatus.Ok, data);
    public static ServiceResult<T> NotFound() => new(ServiceStatus.NotFound, null);
    public static ServiceResult<T> Forbidden() => new(ServiceStatus.Forbidden, null);
    public static ServiceResult<T> Conflict() => new(ServiceStatus.Conflict, null);
    public static ServiceResult<T> Unauthorized() => new(ServiceStatus.Unauthorized, null);
    public static ServiceResult<T> BadRequest() => new(ServiceStatus.BadRequest, null);
}
