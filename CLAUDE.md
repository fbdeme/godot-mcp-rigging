# godot-mcp-rigging

Godot MCP 서버 — 2D 캐릭터 리깅 특화 도구. ee0pdt/Godot-MCP fork.

Claude Code가 MCP 프로토콜로 Godot 에디터를 제어하여 "바이브 코딩" 스타일로 캐릭터를 리깅합니다.

## 구조

```
godot-mcp-rigging/
├── server/                    # TypeScript MCP 서버 (stdio → WebSocket)
│   ├── src/tools/             # MCP 도구 정의 (Zod 스키마)
│   │   ├── node_tools.ts      # 기본 노드 CRUD (원본)
│   │   ├── rigging_tools.ts   # 2D 리깅 도구 (우리가 추가)
│   │   └── animation_tools.ts # 애니메이션 도구 (우리가 추가)
│   └── dist/                  # 빌드 결과 (index.js)
├── addons/godot_mcp/          # GDScript 에디터 애드온
│   ├── commands/
│   │   ├── rigging_commands.gd    # Skeleton2D/Bone2D 커맨드 (우리가 추가)
│   │   └── animation_commands.gd  # Animation/AnimationTree 커맨드 (우리가 추가)
│   └── command_handler.gd        # 커맨드 라우터
└── project.godot              # 테스트용 Godot 프로젝트
```

## 빌드 & 실행

```bash
cd server && npm install && npm run build   # TypeScript 빌드
cd server && npm run start                  # MCP 서버 시작
cd server && npm run dev                    # 개발 모드 (auto-rebuild)
```

## 커스텀 도구 (18개)

### 리깅 (8개)
create_skeleton2d, add_bone2d, create_bone_chain, get_skeleton_info,
bind_polygon2d_to_skeleton, set_bone2d_rest, create_sprite_with_texture, setup_ik_chain

### 애니메이션 (10개)
create_animation_player, create_animation, add_animation_track, set_animation_keyframe,
list_animations, get_animation_info, create_animation_tree, add_state_machine_state,
add_state_machine_transition, set_blend_tree_parameter

## 도구 추가 방법

1. `server/src/tools/`에 TypeScript 도구 정의 (Zod 스키마 + sendCommand)
2. `addons/godot_mcp/commands/`에 GDScript 커맨드 프로세서 (MCPBaseCommandProcessor 상속)
3. `command_handler.gd`에 프로세서 등록
4. `server/src/index.ts`에 도구 import + 등록
5. `npx tsc`로 빌드

## 통신 프로토콜

```
Claude Code --stdio/MCP→ TypeScript Server --WebSocket:9080→ Godot Addon
```

WebSocket 메시지: `{ type, params, commandId }` → `{ status, result, commandId }`

## 코드 스타일

- **TypeScript**: camelCase 변수/메서드, PascalCase 클래스, async/await 선호
- **GDScript**: snake_case 변수/메서드, PascalCase 클래스, @tool 데코레이터 필수
