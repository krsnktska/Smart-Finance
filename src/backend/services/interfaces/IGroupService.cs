using SmartFinance.Models.Requests;
using SmartFinance.Models.Responses;

namespace SmartFinance.Services.Interfaces;

public interface IGroupService
{
    Task<List<GroupResponse>> GetAllAsync(Guid userId);
    Task<ServiceResult<GroupResponse>> GetByIdAsync(Guid id, Guid userId);
    Task<GroupResponse> CreateAsync(Guid userId, CreateGroupRequest request);
    Task<ServiceResult<GroupResponse>> UpdateAsync(Guid id, Guid userId, UpdateGroupRequest request);
    Task<ServiceResult> DeleteAsync(Guid id, Guid userId);
    Task<ServiceResult> AddMemberAsync(Guid groupId, Guid currentUserId, Guid targetUserId);
    Task<ServiceResult> RemoveMemberAsync(Guid groupId, Guid currentUserId, Guid targetUserId);
}
