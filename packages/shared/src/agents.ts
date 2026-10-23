import { z } from 'zod';

export const agentKeySchema = z.enum([
  'manager',
  'triage',
  'support_n1',
  'infra',
  'dev',
  'qa',
  'docs',
]);
export type AgentKey = z.infer<typeof agentKeySchema>;

export const roomSchema = z.enum([
  'manager_office',
  'reception',
  'support_island',
  'server_room',
  'dev_island',
  'library',
  'meeting_room',
]);
export type Room = z.infer<typeof roomSchema>;

export const modelTierSchema = z.enum(['fast', 'strong']);
export type ModelTier = z.infer<typeof modelTierSchema>;

export const agentDefinitionSchema = z.object({
  key: agentKeySchema,
  name: z.string().min(1),
  role: z.string().min(1),
  avatar: z.string().min(1),
  modelTier: modelTierSchema,
  tools: z.array(z.string()),
  permissions: z.array(z.string()),
  room: roomSchema,
  desk: z.string().min(1),
  maxSteps: z.number().int().positive(),
  maxTokens: z.number().int().positive(),
  timeoutMs: z.number().int().positive(),
});
export type AgentDefinition = z.infer<typeof agentDefinitionSchema>;
