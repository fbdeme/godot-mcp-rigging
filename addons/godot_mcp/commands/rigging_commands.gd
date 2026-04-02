@tool
class_name MCPRiggingCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"create_skeleton2d":
			_create_skeleton2d(client_id, params, command_id)
			return true
		"add_bone2d":
			_add_bone2d(client_id, params, command_id)
			return true
		"get_skeleton_info":
			_get_skeleton_info(client_id, params, command_id)
			return true
		"create_bone_chain":
			_create_bone_chain(client_id, params, command_id)
			return true
		"bind_polygon2d_to_skeleton":
			_bind_polygon2d_to_skeleton(client_id, params, command_id)
			return true
		"set_bone2d_rest":
			_set_bone2d_rest(client_id, params, command_id)
			return true
		"create_sprite_with_texture":
			_create_sprite_with_texture(client_id, params, command_id)
			return true
		"setup_ik_chain":
			_setup_ik_chain(client_id, params, command_id)
			return true
	return false


func _create_skeleton2d(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path = params.get("parent_path", "/root")
	var skeleton_name = params.get("name", "Skeleton2D")

	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found", command_id)

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)

	var parent = _get_editor_node(parent_path)
	if not parent:
		return _send_error(client_id, "Parent node not found: %s" % parent_path, command_id)

	var skeleton = Skeleton2D.new()
	skeleton.name = skeleton_name
	parent.add_child(skeleton)
	skeleton.owner = edited_scene_root

	_mark_scene_modified()
	_send_success(client_id, {
		"skeleton_path": str(skeleton.get_path()),
		"name": skeleton_name
	}, command_id)


func _add_bone2d(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path = params.get("parent_path", "")
	var bone_name = params.get("name", "Bone2D")
	var position_x = params.get("position_x", 0.0)
	var position_y = params.get("position_y", 0.0)
	var length = params.get("length", 32.0)
	var rotation_deg = params.get("rotation", 0.0)

	if parent_path.is_empty():
		return _send_error(client_id, "parent_path is required", command_id)

	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found", command_id)

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)

	var parent = _get_editor_node(parent_path)
	if not parent:
		return _send_error(client_id, "Parent node not found: %s" % parent_path, command_id)

	# Parent must be Skeleton2D or Bone2D
	if not (parent is Skeleton2D or parent is Bone2D):
		return _send_error(client_id, "Parent must be Skeleton2D or Bone2D, got: %s" % parent.get_class(), command_id)

	var bone = Bone2D.new()
	bone.name = bone_name
	bone.position = Vector2(position_x, position_y)
	bone.rotation = deg_to_rad(rotation_deg)
	bone.set_meta("bone_length", length)

	parent.add_child(bone)
	bone.owner = edited_scene_root

	# Set the rest transform after adding to tree
	bone.set_rest(bone.get_transform())

	_mark_scene_modified()
	_send_success(client_id, {
		"bone_path": str(bone.get_path()),
		"name": bone_name,
		"position": {"x": position_x, "y": position_y},
		"length": length,
		"rotation": rotation_deg
	}, command_id)


func _get_skeleton_info(client_id: int, params: Dictionary, command_id: String) -> void:
	var skeleton_path = params.get("skeleton_path", "")

	if skeleton_path.is_empty():
		return _send_error(client_id, "skeleton_path is required", command_id)

	var skeleton = _get_editor_node(skeleton_path)
	if not skeleton:
		return _send_error(client_id, "Skeleton not found: %s" % skeleton_path, command_id)

	if not skeleton is Skeleton2D:
		return _send_error(client_id, "Node is not Skeleton2D: %s" % skeleton_path, command_id)

	var bones = []
	_collect_bones(skeleton, bones)

	_send_success(client_id, {
		"skeleton_path": skeleton_path,
		"bone_count": skeleton.get_bone_count(),
		"bones": bones
	}, command_id)


func _collect_bones(node: Node, bones: Array, depth: int = 0) -> void:
	for child in node.get_children():
		if child is Bone2D:
			bones.append({
				"name": child.name,
				"path": str(child.get_path()),
				"position": {"x": child.position.x, "y": child.position.y},
				"rotation": rad_to_deg(child.rotation),
				"depth": depth
			})
			_collect_bones(child, bones, depth + 1)


func _create_bone_chain(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path = params.get("parent_path", "")
	var base_name = params.get("base_name", "Bone")
	var bone_count = params.get("bone_count", 3)
	var bone_length = params.get("bone_length", 32.0)
	var direction_deg = params.get("direction", 0.0)

	if parent_path.is_empty():
		return _send_error(client_id, "parent_path is required", command_id)

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

	if not (parent is Skeleton2D or parent is Bone2D):
		return _send_error(client_id, "Parent must be Skeleton2D or Bone2D", command_id)

	var direction_rad = deg_to_rad(direction_deg)
	var created_bones = []
	var current_parent = parent

	for i in range(bone_count):
		var bone = Bone2D.new()
		bone.name = "%s_%d" % [base_name, i]

		if i == 0:
			bone.position = Vector2.ZERO
		else:
			bone.position = Vector2(bone_length, 0)

		bone.set_meta("bone_length", bone_length)

		if i == 0:
			bone.rotation = direction_rad

		current_parent.add_child(bone)
		bone.owner = edited_scene_root
		bone.set_rest(bone.get_transform())

		created_bones.append({
			"name": bone.name,
			"path": str(bone.get_path())
		})
		current_parent = bone

	_mark_scene_modified()
	_send_success(client_id, {
		"bone_count": bone_count,
		"bones": created_bones
	}, command_id)


func _bind_polygon2d_to_skeleton(client_id: int, params: Dictionary, command_id: String) -> void:
	var polygon_path = params.get("polygon_path", "")
	var skeleton_path = params.get("skeleton_path", "")

	if polygon_path.is_empty() or skeleton_path.is_empty():
		return _send_error(client_id, "polygon_path and skeleton_path are required", command_id)

	var polygon = _get_editor_node(polygon_path)
	if not polygon or not polygon is Polygon2D:
		return _send_error(client_id, "Polygon2D not found: %s" % polygon_path, command_id)

	var skeleton = _get_editor_node(skeleton_path)
	if not skeleton or not skeleton is Skeleton2D:
		return _send_error(client_id, "Skeleton2D not found: %s" % skeleton_path, command_id)

	# Set the skeleton NodePath relative to the Polygon2D
	var rel_path = polygon.get_path_to(skeleton)
	polygon.skeleton = rel_path

	_mark_scene_modified()
	_send_success(client_id, {
		"polygon_path": polygon_path,
		"skeleton_path": skeleton_path,
		"relative_path": str(rel_path)
	}, command_id)


func _set_bone2d_rest(client_id: int, params: Dictionary, command_id: String) -> void:
	var bone_path = params.get("bone_path", "")

	if bone_path.is_empty():
		return _send_error(client_id, "bone_path is required", command_id)

	var bone = _get_editor_node(bone_path)
	if not bone or not bone is Bone2D:
		return _send_error(client_id, "Bone2D not found: %s" % bone_path, command_id)

	# Optionally update transform before setting rest
	if params.has("position_x") or params.has("position_y"):
		var px = params.get("position_x", bone.position.x)
		var py = params.get("position_y", bone.position.y)
		bone.position = Vector2(px, py)

	if params.has("rotation"):
		bone.rotation = deg_to_rad(params.get("rotation", 0.0))

	bone.set_rest(bone.get_transform())

	_mark_scene_modified()
	_send_success(client_id, {
		"bone_path": bone_path,
		"rest_position": {"x": bone.position.x, "y": bone.position.y},
		"rest_rotation": rad_to_deg(bone.rotation)
	}, command_id)


func _create_sprite_with_texture(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path = params.get("parent_path", "/root")
	var sprite_name = params.get("name", "Sprite2D")
	var texture_path = params.get("texture_path", "")
	var position_x = params.get("position_x", 0.0)
	var position_y = params.get("position_y", 0.0)

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

	var sprite = Sprite2D.new()
	sprite.name = sprite_name
	sprite.position = Vector2(position_x, position_y)

	if not texture_path.is_empty():
		var texture = load(texture_path)
		if texture and texture is Texture2D:
			sprite.texture = texture
		else:
			parent.add_child(sprite)
			sprite.owner = edited_scene_root
			_mark_scene_modified()
			return _send_error(client_id, "Texture not found or invalid: %s (sprite created without texture)" % texture_path, command_id)

	parent.add_child(sprite)
	sprite.owner = edited_scene_root

	_mark_scene_modified()
	_send_success(client_id, {
		"sprite_path": str(sprite.get_path()),
		"name": sprite_name,
		"texture": texture_path
	}, command_id)


func _setup_ik_chain(client_id: int, params: Dictionary, command_id: String) -> void:
	var skeleton_path = params.get("skeleton_path", "")
	var tip_bone_path = params.get("tip_bone_path", "")
	var chain_length = params.get("chain_length", 2)
	var target_position_x = params.get("target_x", 0.0)
	var target_position_y = params.get("target_y", 0.0)

	if skeleton_path.is_empty() or tip_bone_path.is_empty():
		return _send_error(client_id, "skeleton_path and tip_bone_path are required", command_id)

	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found", command_id)

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)

	var skeleton = _get_editor_node(skeleton_path)
	if not skeleton or not skeleton is Skeleton2D:
		return _send_error(client_id, "Skeleton2D not found: %s" % skeleton_path, command_id)

	var tip_bone = _get_editor_node(tip_bone_path)
	if not tip_bone or not tip_bone is Bone2D:
		return _send_error(client_id, "Tip Bone2D not found: %s" % tip_bone_path, command_id)

	# Create SkeletonModification2D stack if needed
	var mod_stack = skeleton.get_modification_stack()
	if not mod_stack:
		mod_stack = SkeletonModificationStack2D.new()
		mod_stack.enabled = true
		mod_stack.modification_count = 0
		skeleton.set_modification_stack(mod_stack)

	# Create IK modification
	var ik_mod = SkeletonModification2DTwoBoneIK.new()
	ik_mod.set_target_node(tip_bone.get_path())

	# Add to stack
	mod_stack.modification_count += 1
	mod_stack.set_modification(mod_stack.modification_count - 1, ik_mod)

	_mark_scene_modified()
	_send_success(client_id, {
		"skeleton_path": skeleton_path,
		"tip_bone": tip_bone_path,
		"ik_type": "TwoBoneIK"
	}, command_id)
