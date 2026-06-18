extends Node

var selected_entity: GroundEntity = null

func _unhandled_input(event):
	if not (event is InputEventMouseButton and event.pressed):
		return

	var button = event.button_index
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 8000

	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF   # alles treffen

	var result = space_state.intersect_ray(query)

	if result:
		var hit = result.collider.get_parent()
		while hit and not hit is GroundEntity:
			hit = hit.get_parent()

		if hit is GroundEntity:
			if button == MOUSE_BUTTON_LEFT:
				_select(hit)
			elif button == MOUSE_BUTTON_RIGHT:
				_move_selected(result.position, hit)
	else:
		if button == MOUSE_BUTTON_LEFT:
			_deselect()

func _select(entity: GroundEntity):
	_deselect()
	selected_entity = entity
	entity.select()

func _deselect():
	if selected_entity:
		selected_entity.deselect()
		selected_entity = null

func _move_selected(world_pos: Vector3, entity: GroundEntity):
	if entity == null:
		return

	var target_pos = world_pos.normalized() * 1002.0
	var new_lat = rad_to_deg(asin(target_pos.y / 1002.0))
	var new_lon = rad_to_deg(atan2(target_pos.x, target_pos.z))

	entity.move_to(new_lat, new_lon)
