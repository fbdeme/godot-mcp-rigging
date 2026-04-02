import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

/**
 * Animation tools for AnimationPlayer and AnimationTree
 */
export const animationTools: MCPTool[] = [
  {
    name: 'create_animation_player',
    description: 'Create an AnimationPlayer node',
    parameters: z.object({
      parent_path: z.string()
        .describe('Path to the parent node'),
      name: z.string().default('AnimationPlayer')
        .describe('Name for the AnimationPlayer'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('create_animation_player', args);
      return `Created AnimationPlayer "${result.name}" at ${result.player_path}`;
    },
  },

  {
    name: 'create_animation',
    description: 'Create a new animation clip in an AnimationPlayer',
    parameters: z.object({
      player_path: z.string()
        .describe('Path to the AnimationPlayer'),
      name: z.string().default('idle')
        .describe('Name for the animation (e.g. "idle", "talk", "blink")'),
      duration: z.number().default(1.0)
        .describe('Animation duration in seconds'),
      loop_mode: z.enum(['none', 'linear', 'pingpong']).default('linear')
        .describe('Loop mode: "none", "linear" (default), or "pingpong"'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('create_animation', args);
      return `Created animation "${result.animation_name}" (${result.duration}s, loop: ${result.loop_mode})`;
    },
  },

  {
    name: 'add_animation_track',
    description: 'Add a property track to an animation. Tracks animate specific node properties over time.',
    parameters: z.object({
      player_path: z.string()
        .describe('Path to the AnimationPlayer'),
      animation_name: z.string()
        .describe('Name of the animation to add the track to'),
      node_path: z.string()
        .describe('Path to the node being animated'),
      track_type: z.enum(['value', 'position', 'rotation', 'scale']).default('value')
        .describe('Track type: "value" (custom property), "position", "rotation", or "scale"'),
      property: z.string().default('')
        .describe('Property name for value tracks (e.g. "modulate", "visible")'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('add_animation_track', args);
      return `Added ${result.track_type} track [${result.track_index}] → ${result.track_path}`;
    },
  },

  {
    name: 'set_animation_keyframe',
    description: 'Insert a keyframe at a specific time in an animation track',
    parameters: z.object({
      player_path: z.string()
        .describe('Path to the AnimationPlayer'),
      animation_name: z.string()
        .describe('Name of the animation'),
      track_index: z.number()
        .describe('Track index (returned by add_animation_track)'),
      time: z.number()
        .describe('Time position in seconds'),
      value: z.any()
        .describe('Keyframe value (use Godot type strings for vectors, e.g. "Vector2(100, 200)")'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('set_animation_keyframe', args);
      return `Set keyframe at ${result.time}s on track [${result.track_index}] = ${result.value}`;
    },
  },

  {
    name: 'list_animations',
    description: 'List all animations in an AnimationPlayer',
    parameters: z.object({
      player_path: z.string()
        .describe('Path to the AnimationPlayer'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('list_animations', args);
      if (result.animations.length === 0) {
        return `No animations in ${result.player_path}`;
      }
      const list = result.animations.map((a: any) =>
        `  ${a.name} (${a.duration}s, ${a.track_count} tracks, loop: ${a.loop_mode})`
      ).join('\n');
      return `Animations in ${result.player_path}:\n${list}`;
    },
  },

  {
    name: 'get_animation_info',
    description: 'Get detailed info about an animation including all tracks and keyframes',
    parameters: z.object({
      player_path: z.string()
        .describe('Path to the AnimationPlayer'),
      animation_name: z.string()
        .describe('Name of the animation'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('get_animation_info', args);
      const tracks = result.tracks.map((t: any) => {
        const keys = t.keys.map((k: any) => `    @${k.time}s = ${k.value}`).join('\n');
        return `  [${t.index}] ${t.path} (${t.key_count} keys)\n${keys}`;
      }).join('\n');
      return `Animation "${result.animation_name}" (${result.duration}s, ${result.track_count} tracks):\n${tracks}`;
    },
  },

  {
    name: 'create_animation_tree',
    description: 'Create an AnimationTree with a state machine or blend tree as root',
    parameters: z.object({
      parent_path: z.string()
        .describe('Path to the parent node'),
      name: z.string().default('AnimationTree')
        .describe('Name for the AnimationTree'),
      player_path: z.string().default('')
        .describe('Path to the AnimationPlayer to link'),
      root_type: z.enum(['state_machine', 'blend_tree']).default('state_machine')
        .describe('Root node type'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('create_animation_tree', args);
      return `Created AnimationTree "${result.name}" at ${result.tree_path} (root: ${result.root_type})`;
    },
  },

  {
    name: 'add_state_machine_state',
    description: 'Add a state to the AnimationTree state machine',
    parameters: z.object({
      tree_path: z.string()
        .describe('Path to the AnimationTree'),
      state_name: z.string()
        .describe('Name for the state (e.g. "idle", "talk", "blink")'),
      animation_name: z.string().default('')
        .describe('Animation to play in this state'),
      position_x: z.number().default(0)
        .describe('X position in the state machine editor'),
      position_y: z.number().default(0)
        .describe('Y position in the state machine editor'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('add_state_machine_state', args);
      return `Added state "${result.state_name}" → animation "${result.animation_name}"`;
    },
  },

  {
    name: 'add_state_machine_transition',
    description: 'Add a transition between two states in the state machine',
    parameters: z.object({
      tree_path: z.string()
        .describe('Path to the AnimationTree'),
      from_state: z.string()
        .describe('Source state name'),
      to_state: z.string()
        .describe('Target state name'),
      auto_advance: z.boolean().default(false)
        .describe('Automatically advance when source animation finishes'),
      switch_mode: z.enum(['immediate', 'sync', 'at_end']).default('immediate')
        .describe('When to switch: "immediate", "sync", or "at_end"'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('add_state_machine_transition', args);
      return `Added transition: ${result.from} → ${result.to} (auto: ${result.auto_advance}, mode: ${result.switch_mode})`;
    },
  },

  {
    name: 'set_blend_tree_parameter',
    description: 'Set a parameter value on an AnimationTree (used for blend amounts, conditions, etc.)',
    parameters: z.object({
      tree_path: z.string()
        .describe('Path to the AnimationTree'),
      parameter: z.string()
        .describe('Parameter name (without "parameters/" prefix)'),
      value: z.any()
        .describe('Parameter value (number for blends, bool for conditions)'),
    }),
    execute: async (args): Promise<string> => {
      const godot = getGodotConnection();
      const result = await godot.sendCommand<CommandResult>('set_blend_tree_parameter', args);
      return `Set parameter "${result.parameter}" = ${result.value}`;
    },
  },
];
