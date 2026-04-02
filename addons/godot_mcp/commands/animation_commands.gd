@tool
class_name MCPAnimationCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"create_animation_player":
			_create_animation_player(client_id, params, command_id)
			return true
		"create_animation":
			_create_animation(client_id, params, command_id)
			return true
		"add_animation_track":
			_add_animation_track(client_id, params, command_id)
			return true
		"set_animation_keyframe":
			_set_animation_keyframe(client_id, params, command_id)
			return true
		"list_animations":
			_list_animations(client_id, params, command_id)
			return true
		"get_animation_info":
			_get_animation_info(client_id, params, command_id)
			return true
		"create_animation_tree":
			_create_animation_tree(client_id, params, command_id)
			return true
		"add_state_machine_state":
			_add_state_machine_state(client_id, params, command_id)
			return true
		"add_state_machine_transition":
			_add_state_machine_transition(client_id, params, command_id)
			return true
		"set_blend_tree_parameter":
			_set_blend_tree_parameter(client_id, params, command_id)
			return true
	return false


func _create_animation_player(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path = params.get("parent_path", "/root")
	var player_name = params.get("name", "AnimationPlayer")

	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found", command_id)

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)

	var parent = _get_editor_node(parent_path)
	if not parent:
		return _send_error(client_id, "Parent not found: %s" % parent_path, command_id)

	var player = AnimationPlayer.new()
	player.name = player_name
	parent.add_child(player)
	player.owner = edited_scene_root

	_mark_scene_modified()
	_send_success(client_id, {
		"player_path": str(player.get_path()),
		"name": player_name
	}, command_id)


func _create_animation(client_id: int, params: Dictionary, command_id: String) -> void:
	var player_path = params.get("player_path", "")
	var anim_name = params.get("name", "idle")
	var duration = params.get("duration", 1.0)
	var loop_mode = params.get("loop_mode", "linear")  # "none", "linear", "pingpong"

	if player_path.is_empty():
		return _send_error(client_id, "player_path is required", command_id)

	var player = _get_editor_node(player_path)
	if not player or not player is AnimationPlayer:
		return _send_error(client_id, "AnimationPlayer not found: %s" % player_path, command_id)

	# Create AnimationLibrary if not exists
	var lib: AnimationLibrary
	if player.has_animation_library(""):
		lib = player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)

	var anim = Animation.new()
	anim.length = duration

	match loop_mode:
		"linear":
			anim.loop_mode = Animation.LOOP_LINEAR
		"pingpong":
			anim.loop_mode = Animation.LOOP_PINGPONG
		_:
			anim.loop_mode = Animation.LOOP_NONE

	lib.add_animation(anim_name, anim)

	_mark_scene_modified()
	_send_success(client_id, {
		"player_path": player_path,
		"animation_name": anim_name,
		"duration": duration,
		"loop_mode": loop_mode
	}, command_id)


func _add_animation_track(client_id: int, params: Dictionary, command_id: String) -> void:
	var player_path = params.get("player_path", "")
	var anim_name = params.get("animation_name", "")
	var node_path = params.get("node_path", "")
	var property = params.get("property", "")
	var track_type = params.get("track_type", "value")  # "value", "position", "rotation", "scale"

	if player_path.is_empty() or anim_name.is_empty() or node_path.is_empty():
		return _send_error(client_id, "player_path, animation_name, and node_path are required", command_id)

	var player = _get_editor_node(player_path)
	if not player or not player is AnimationPlayer:
		return _send_error(client_id, "AnimationPlayer not found: %s" % player_path, command_id)

	if not player.has_animation(anim_name):
		return _send_error(client_id, "Animation not found: %s" % anim_name, command_id)

	var anim = player.get_animation(anim_name)

	# Build the track path relative to AnimationPlayer's root
	var target_node = _get_editor_node(node_path)
	if not target_node:
		return _send_error(client_id, "Target node not found: %s" % node_path, command_id)

	var root_node = player.get_node(player.root_node)
	var rel_path = str(root_node.get_path_to(target_node))

	var track_idx: int
	var full_path: String

	match track_type:
		"position":
			track_idx = anim.add_track(Animation.TYPE_VALUE)
			full_path = rel_path + ":position"
		"rotation":
			track_idx = anim.add_track(Animation.TYPE_VALUE)
			full_path = rel_path + ":rotation"
		"scale":
			track_idx = anim.add_track(Animation.TYPE_VALUE)
			full_path = rel_path + ":scale"
		_:  # "value"
			track_idx = anim.add_track(Animation.TYPE_VALUE)
			if property.is_empty():
				return _send_error(client_id, "property is required for value tracks", command_id)
			full_path = rel_path + ":" + property

	anim.track_set_path(track_idx, full_path)

	_mark_scene_modified()
	_send_success(client_id, {
		"track_index": track_idx,
		"track_path": full_path,
		"track_type": track_type,
		"animation_name": anim_name
	}, command_id)


func _set_animation_keyframe(client_id: int, params: Dictionary, command_id: String) -> void:
	var player_path = params.get("player_path", "")
	var anim_name = params.get("animation_name", "")
	var track_index = params.get("track_index", 0)
	var time = params.get("time", 0.0)
	var value = params.get("value")

	if player_path.is_empty() or anim_name.is_empty():
		return _send_error(client_id, "player_path and animation_name are required", command_id)

	var player = _get_editor_node(player_path)
	if not player or not player is AnimationPlayer:
		return _send_error(client_id, "AnimationPlayer not found: %s" % player_path, command_id)

	if not player.has_animation(anim_name):
		return _send_error(client_id, "Animation not found: %s" % anim_name, command_id)

	var anim = player.get_animation(anim_name)

	if track_index < 0 or track_index >= anim.get_track_count():
		return _send_error(client_id, "Invalid track index: %d" % track_index, command_id)

	# Parse the value
	var parsed_value = _parse_property_value(value)
	anim.track_insert_key(track_index, time, parsed_value)

	_mark_scene_modified()
	_send_success(client_id, {
		"animation_name": anim_name,
		"track_index": track_index,
		"time": time,
		"value": str(parsed_value)
	}, command_id)


func _list_animations(client_id: int, params: Dictionary, command_id: String) -> void:
	var player_path = params.get("player_path", "")

	if player_path.is_empty():
		return _send_error(client_id, "player_path is required", command_id)

	var player = _get_editor_node(player_path)
	if not player or not player is AnimationPlayer:
		return _send_error(client_id, "AnimationPlayer not found: %s" % player_path, command_id)

	var animations = []
	for lib_name in player.get_animation_library_list():
		var lib = player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var anim = lib.get_animation(anim_name)
			var full_name = anim_name if lib_name == "" else lib_name + "/" + anim_name
			animations.append({
				"name": full_name,
				"duration": anim.length,
				"loop_mode": anim.loop_mode,
				"track_count": anim.get_track_count()
			})

	_send_success(client_id, {
		"player_path": player_path,
		"animations": animations
	}, command_id)


func _get_animation_info(client_id: int, params: Dictionary, command_id: String) -> void:
	var player_path = params.get("player_path", "")
	var anim_name = params.get("animation_name", "")

	if player_path.is_empty() or anim_name.is_empty():
		return _send_error(client_id, "player_path and animation_name are required", command_id)

	var player = _get_editor_node(player_path)
	if not player or not player is AnimationPlayer:
		return _send_error(client_id, "AnimationPlayer not found: %s" % player_path, command_id)

	if not player.has_animation(anim_name):
		return _send_error(client_id, "Animation not found: %s" % anim_name, command_id)

	var anim = player.get_animation(anim_name)
	var tracks = []

	for i in range(anim.get_track_count()):
		var track_info = {
			"index": i,
			"path": str(anim.track_get_path(i)),
			"type": anim.track_get_type(i),
			"key_count": anim.track_get_key_count(i)
		}

		var keys = []
		for k in range(anim.track_get_key_count(i)):
			keys.append({
				"time": anim.track_get_key_time(i, k),
				"value": str(anim.track_get_key_value(i, k))
			})
		track_info["keys"] = keys
		tracks.append(track_info)

	_send_success(client_id, {
		"animation_name": anim_name,
		"duration": anim.length,
		"loop_mode": anim.loop_mode,
		"track_count": anim.get_track_count(),
		"tracks": tracks
	}, command_id)


func _create_animation_tree(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path = params.get("parent_path", "/root")
	var tree_name = params.get("name", "AnimationTree")
	var player_path = params.get("player_path", "")
	var root_type = params.get("root_type", "state_machine")  # "state_machine", "blend_tree"

	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found", command_id)

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)

	var parent = _get_editor_node(parent_path)
	if not parent:
		return _send_error(client_id, "Parent not found: %s" % parent_path, command_id)

	var tree = AnimationTree.new()
	tree.name = tree_name

	# Set animation player
	if not player_path.is_empty():
		var player = _get_editor_node(player_path)
		if player and player is AnimationPlayer:
			parent.add_child(tree)
			tree.owner = edited_scene_root
			tree.anim_player = tree.get_path_to(player)
		else:
			parent.add_child(tree)
			tree.owner = edited_scene_root
	else:
		parent.add_child(tree)
		tree.owner = edited_scene_root

	# Set root node type
	match root_type:
		"state_machine":
			var sm = AnimationNodeStateMachine.new()
			tree.tree_root = sm
		"blend_tree":
			var bt = AnimationNodeBlendTree.new()
			tree.tree_root = bt

	tree.active = true

	_mark_scene_modified()
	_send_success(client_id, {
		"tree_path": str(tree.get_path()),
		"name": tree_name,
		"root_type": root_type
	}, command_id)


func _add_state_machine_state(client_id: int, params: Dictionary, command_id: String) -> void:
	var tree_path = params.get("tree_path", "")
	var state_name = params.get("state_name", "")
	var animation_name = params.get("animation_name", "")
	var position_x = params.get("position_x", 0.0)
	var position_y = params.get("position_y", 0.0)

	if tree_path.is_empty() or state_name.is_empty():
		return _send_error(client_id, "tree_path and state_name are required", command_id)

	var tree = _get_editor_node(tree_path)
	if not tree or not tree is AnimationTree:
		return _send_error(client_id, "AnimationTree not found: %s" % tree_path, command_id)

	var sm = tree.tree_root
	if not sm or not sm is AnimationNodeStateMachine:
		return _send_error(client_id, "AnimationTree root is not a StateMachine", command_id)

	# Create animation node for the state
	var anim_node: AnimationRootNode
	if not animation_name.is_empty():
		var node = AnimationNodeAnimation.new()
		node.animation = animation_name
		anim_node = node
	else:
		anim_node = AnimationNodeAnimation.new()

	sm.add_node(state_name, anim_node, Vector2(position_x, position_y))

	_mark_scene_modified()
	_send_success(client_id, {
		"tree_path": tree_path,
		"state_name": state_name,
		"animation_name": animation_name
	}, command_id)


func _add_state_machine_transition(client_id: int, params: Dictionary, command_id: String) -> void:
	var tree_path = params.get("tree_path", "")
	var from_state = params.get("from_state", "")
	var to_state = params.get("to_state", "")
	var auto_advance = params.get("auto_advance", false)
	var switch_mode = params.get("switch_mode", "immediate")  # "immediate", "sync", "at_end"

	if tree_path.is_empty() or from_state.is_empty() or to_state.is_empty():
		return _send_error(client_id, "tree_path, from_state, and to_state are required", command_id)

	var tree = _get_editor_node(tree_path)
	if not tree or not tree is AnimationTree:
		return _send_error(client_id, "AnimationTree not found: %s" % tree_path, command_id)

	var sm = tree.tree_root
	if not sm or not sm is AnimationNodeStateMachine:
		return _send_error(client_id, "AnimationTree root is not a StateMachine", command_id)

	var transition = AnimationNodeStateMachineTransition.new()
	transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO if auto_advance else AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED

	match switch_mode:
		"sync":
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
		"at_end":
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		_:
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE

	sm.add_transition(from_state, to_state, transition)

	_mark_scene_modified()
	_send_success(client_id, {
		"from": from_state,
		"to": to_state,
		"auto_advance": auto_advance,
		"switch_mode": switch_mode
	}, command_id)


func _set_blend_tree_parameter(client_id: int, params: Dictionary, command_id: String) -> void:
	var tree_path = params.get("tree_path", "")
	var parameter_name = params.get("parameter", "")
	var value = params.get("value")

	if tree_path.is_empty() or parameter_name.is_empty():
		return _send_error(client_id, "tree_path and parameter are required", command_id)

	var tree = _get_editor_node(tree_path)
	if not tree or not tree is AnimationTree:
		return _send_error(client_id, "AnimationTree not found: %s" % tree_path, command_id)

	# AnimationTree parameters are set via "parameters/" prefix
	var param_path = "parameters/" + parameter_name
	tree.set(param_path, value)

	_mark_scene_modified()
	_send_success(client_id, {
		"tree_path": tree_path,
		"parameter": parameter_name,
		"value": value
	}, command_id)
