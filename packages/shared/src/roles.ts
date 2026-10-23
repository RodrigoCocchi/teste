import { z } from 'zod';

export const roleSchema = z.enum(['owner', 'admin', 'viewer']);
export type Role = z.infer<typeof roleSchema>;

const ROLE_RANK: Record<Role, number> = { viewer: 0, admin: 1, owner: 2 };

/** `true` quando `role` tem pelo menos as permissões de `required`. */
export function hasRole(role: Role, required: Role): boolean {
  return ROLE_RANK[role] >= ROLE_RANK[required];
}
