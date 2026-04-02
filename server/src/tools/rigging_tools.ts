import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

/**
 * 2D rigging tools for Skeleton2D, Bone2D, and mesh binding
 */
export const riggingTools: MCPTool[] = [
  {
    name: 'create_skeleton2d',
    description: 'Create a Skeleton2D node for 2D character rigging',
    parameters: z.object({
      parent_path: z.string()
        .describe('Path to the parent node (e.g. "/root/Character")'),
      name: z.string().default('Skeleton2D')
        .describe('Name for the Skeleton2D node'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('create_skeleton2d', args);
      return `Created Skeleton2D "${result.name}" at ${result.skeleton_path}`;
    },
  },

  {
    name: 'add_bone2d',
    description: 'Add a Bone2D to a Skeleton2D or another Bone2D. Parent must be Skeleton2D or Bone2D.',
    parameters: z.object({
      parent_path: z.string()
        .describe('Path to parent Skeleton2D or Bone2D node'),
      name: z.string().default('Bone2D')
        .describe('Name for the bone'),
      position_x: z.number().default(0)
        .describe('X position relative to parent'),
      position_y: z.number().default(0)
        .describe('Y position relative to parent'),
      length: z.number().default(32)
        .describe('Visual length of the bone'),
      rotation: z.number().default(0)
        .describe('Rotation in degrees'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('add_bone2d', args);
      return `Added Bone2D "${result.name}" at ${result.bone_path} (pos: ${result.position.x},${result.position.y}, rot: ${result.rotation}°)`;
    },
  },

  {
    name: 'get_skeleton_info',
    description: 'Get full bone hierarchy information from a Skeleton2D',
    parameters: z.object({
      skeleton_path: z.string()
        .describe('Path to the Skeleton2D node'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('get_skeleton_info', args);
      const bones = result.bones.map((b: any) =>
        `${'  '.repeat(b.depth)}${b.name} (pos: ${b.position.x},${b.position.y}, rot: ${b.rotation}°)`
      ).join('\n');
      return `Skeleton at ${result.skeleton_path} — ${result.bone_count} bones:\n${bones}`;
    },
  },

  {
    name: 'create_bone_chain',
    description: 'Create a chain of connected Bone2D nodes (e.g. for arm: shoulder→elbow→wrist)',
    parameters: z.object({
      parent_path: z.string()
        .describe('Path to parent Skeleton2D or Bone2D'),
      base_name: z.string().default('Bone')
        .describe('Base name for bones (will be suffixed with _0, _1, etc.)'),
      bone_count: z.number().default(3)
        .describe('Number of bones in the chain'),
      bone_length: z.number().default(32)
        .describe('Length of each bone segment'),
      direction: z.number().default(0)
        .describe('Direction angle in degrees for the first bone'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('create_bone_chain', args);
      const names = result.bones.map((b: any) => b.name).join(' → ');
      return `Created bone chain (${result.bone_count} bones): ${names}`;
    },
  },

  {
    name: 'bind_polygon2d_to_skeleton',
    description: 'Bind a Polygon2D node to a Skeleton2D for mesh deformation',
    parameters: z.object({
      polygon_path: z.string()
        .describe('Path to the Polygon2D node'),
      skeleton_path: z.string()
        .describe('Path to the Skeleton2D node'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('bind_polygon2d_to_skeleton', args);
      return `Bound Polygon2D to Skeleton2D (relative path: ${result.relative_path})`;
    },
  },

  {
    name: 'set_bone2d_rest',
    description: 'Set or update the rest transform of a Bone2D. Optionally update position/rotation before setting rest.',
    parameters: z.object({
      bone_path: z.string()
        .describe('Path to the Bone2D node'),
      position_x: z.number().optional()
        .describe('New X position (optional)'),
      position_y: z.number().optional()
        .describe('New Y position (optional)'),
      rotation: z.number().optional()
        .describe('New rotation in degrees (optional)'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('set_bone2d_rest', args);
      return `Set rest for bone at ${result.bone_path} (pos: ${result.rest_position.x},${result.rest_position.y}, rot: ${result.rest_rotation}°)`;
    },
  },

  {
    name: 'create_sprite_with_texture',
    description: 'Create a Sprite2D node and optionally load a texture from the project resources',
    parameters: z.object({
      parent_path: z.string()
        .describe('Path to the parent node'),
      name: z.string().default('Sprite2D')
        .describe('Name for the sprite'),
      texture_path: z.string().default('')
        .describe('Resource path to texture (e.g. "res://assets/face.png")'),
      position_x: z.number().default(0)
        .describe('X position'),
      position_y: z.number().default(0)
        .describe('Y position'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('create_sprite_with_texture', args);
      return `Created Sprite2D "${result.name}" at ${result.sprite_path}` +
        (result.texture ? ` with texture ${result.texture}` : '');
    },
  },

  {
    name: 'setup_ik_chain',
    description: 'Set up inverse kinematics (TwoBoneIK) on a Skeleton2D',
    parameters: z.object({
      skeleton_path: z.string()
        .describe('Path to the Skeleton2D node'),
      tip_bone_path: z.string()
        .describe('Path to the tip Bone2D (end of IK chain)'),
      chain_length: z.number().default(2)
        .describe('Number of bones in the IK chain'),
      target_x: z.number().default(0)
        .describe('Target X position'),
      target_y: z.number().default(0)
        .describe('Target Y position'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('setup_ik_chain', args);
      return `Set up ${result.ik_type} on skeleton ${result.skeleton_path} with tip bone ${result.tip_bone}`;
    },
  },
];
