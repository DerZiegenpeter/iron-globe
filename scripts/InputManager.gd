extends Node

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var camera = get_viewport().get_camera_3d()
		if not camera:
			return

		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 5000

		var space_state = get_viewport().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			var hit = result.collider.get_parent()

			# Finde den GroundEntity (auch wenn Area3D oder CollisionShape getroffen wurde)
			while hit and not hit is GroundEntity:
				hit = hit.get_parent()

			if hit is GroundEntity:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_handle_left_click(hit)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_handle_right_click(hit, result.position)

func _handle_left_click(entity: GroundEntity):
	get_tree().call_group("ground_entities", "deselect")
	entity.select()
	entity.add_to_group("selected", true)

func _handle_right_click(entity: GroundEntity, click_world_pos: Vector3):
	var new_pos = click_world_pos.normalized() * 1002.0
	var new_lat = rad_to_deg(asin(new_pos.y / 1002.0))
	var new_lon = rad_to_deg(atan2(new_pos.x, new_pos.z))
	
	entity.move_to(new_lat, new_lon)
	print("Bewegung befohlen:", entity.entity_name, "→ Lat:", new_lat, "Lon:", new_lon)
