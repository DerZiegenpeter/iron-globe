extends Node

var selected_entity: GroundEntity = null

@onready var game_data: Node = get_node_or_null("/root/GameData")

func _unhandled_input(event):
	if get_viewport().is_input_handled():
		return
	
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	var button = event.button_index
	if button != MOUSE_BUTTON_LEFT and button != MOUSE_BUTTON_RIGHT:
		return

	var camera = get_viewport().get_camera_3d()
	if not camera: return

	var from = camera.project_ray_origin(event.position)
	var ray_normal = camera.project_ray_normal(event.position)
	var to = from + ray_normal * 5000

	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 1 | 2

	var result = space_state.intersect_ray(query)

	if result:
		var hit = result.collider.get_parent()
		while hit and not hit is GroundEntity:
			hit = hit.get_parent()

		if hit is GroundEntity:
			if button == MOUSE_BUTTON_LEFT:
				_select(hit)
			elif button == MOUSE_BUTTON_RIGHT:
				_move_selected(result.position)
			get_viewport().set_input_as_handled()
		else:
			if button == MOUSE_BUTTON_LEFT:
				_deselect()
				if game_data and game_data.has_method("deselect_province"):
					game_data.deselect_province()
	else:
		if button == MOUSE_BUTTON_LEFT:
			_deselect()
			if game_data and game_data.has_method("deselect_province"):
				game_data.deselect_province()

func _select(entity: GroundEntity):
	_deselect()
	selected_entity = entity
	entity.select()
	if game_data and game_data.has_method("deselect_province"):
		game_data.deselect_province()
	print(">>> Military Entity selected: ", entity.entity_name)

func _deselect():
	if selected_entity:
		selected_entity.deselect()
		selected_entity = null

func _move_selected(world_pos: Vector3):
	if selected_entity == null:
		return
	
	var target_pos = world_pos.normalized() * 1002.0
	var new_lat = rad_to_deg(asin(target_pos.y / 1002.0))
	var new_lon = rad_to_deg(atan2(target_pos.x, target_pos.z))
	
	# Nur noch 2 Argumente (neue Signatur von move_to)
	selected_entity.move_to(new_lat, new_lon)
