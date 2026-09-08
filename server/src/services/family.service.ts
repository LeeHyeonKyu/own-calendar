import { groupService } from './group.service';

// Backwards-compatible wrapper that delegates to group service.
// The /api/family routes still work but internally use the Group model.
export const familyService = {
  async create(userId: string, name: string) {
    return groupService.create(userId, name, '가족');
  },

  async getMyFamily(userId: string) {
    const groups = await groupService.getMyGroups(userId);
    // Return the first group for backwards compatibility
    return groups.length > 0 ? groups[0] : null;
  },

  async join(userId: string, code: string) {
    return groupService.join(userId, code);
  },

  async getMembers(userId: string) {
    const groups = await groupService.getMyGroups(userId);
    if (groups.length === 0) {
      const error = new Error('Not a member of any family group');
      (error as any).statusCode = 404;
      throw error;
    }
    const group = await groupService.getGroup(userId, groups[0].id);
    return group.members;
  },

  async removeMember(userId: string, targetUserId: string) {
    const groups = await groupService.getMyGroups(userId);
    if (groups.length === 0) {
      const error = new Error('Not a member of any family group');
      (error as any).statusCode = 404;
      throw error;
    }
    return groupService.removeMember(userId, groups[0].id, targetUserId);
  },

  async getFamilyCalendars(userId: string, query?: { start?: string; end?: string }) {
    return groupService.getAllGroupCalendars(userId, query);
  },

  async createFamilyEvent(
    userId: string,
    data: {
      title: string;
      description?: string;
      startTime: string;
      endTime: string;
      isAllDay?: boolean;
      isPrivate?: boolean;
    },
  ) {
    const groups = await groupService.getMyGroups(userId);
    if (groups.length === 0) {
      const error = new Error('Not a member of any family group');
      (error as any).statusCode = 404;
      throw error;
    }
    return groupService.createGroupEvent(userId, groups[0].id, data);
  },
};
