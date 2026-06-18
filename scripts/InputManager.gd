extends Node

var selected_entity: GroundEntity = null

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		
		if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
			return

		var camera = get_viewport().get_camera_3d()
		if not camera: return

		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 5000

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
				if event.button_index == MOUSE_BUTTON_LEFT:
					_select(hit)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_move_selected(result.position)
			else:
				# Kein GroundEntity → Klick durchlassen für ClickHandler (States)
				pass
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				pass   # Klick durchlassen

func _select(entity: GroundEntity):
	_deselect()
	selected_entity = entity
	entity.select()

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
	
	print(">>> Bewege", selected_entity.entity_name, "nach Lat:", new_lat, "Lon:", new_lon)
	selected_entity.move_to(new_lat, new_lon, 6.0)
