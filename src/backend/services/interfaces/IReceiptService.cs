using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IReceiptService
{
    Task<ServiceResult<ReceiptScanResponse>> ScanPhotoAsync(IFormFile image, Guid accountId, Guid userId);
    Task<ServiceResult<ReceiptScanResponse>> ScrapeUrlAsync(ScrapeReceiptRequest request, Guid userId);
}
