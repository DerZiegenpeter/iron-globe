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

	# ==================== DEBUG ====================
	if button == MOUSE_BUTTON_RIGHT:
		print(">>> DEBUG RIGHT-CLICK detected")
		if result:
			print("    Ray hit at world pos: ", result.position)
			print("    Hit collider layer: ", result.collider.collision_layer)
		else:
			print("    Ray hit NOTHING (sky or far away)")
	# ===============================================

	if result:
		var hit = result.collider.get_parent()
		while hit and not hit is GroundEntity:
			hit = hit.get_parent()

		if hit is GroundEntity:
			if button == MOUSE_BUTTON_LEFT:
				_select(hit)
			elif button == MOUSE_BUTTON_RIGHT:
				print(">>> DEBUG: Right-click on ENTITY collider → moving")
				_move_selected(result.position)
			get_viewport().set_input_as_handled()
		else:
			# Hit something else (State border etc.)
			if button == MOUSE_BUTTON_LEFT:
				_deselect()
				if game_data and game_data.has_method("deselect_province"):
					game_data.deselect_province()
			elif button == MOUSE_BUTTON_RIGHT:
				if selected_entity != null:
					print(">>> DEBUG: Right-click on globe (not on entity) → moving selected unit")
					_move_selected(result.position)
					get_viewport().set_input_as_handled()
	else:
		# No physics hit at all
		if button == MOUSE_BUTTON_LEFT:
			_deselect()
			if game_data and game_data.has_method("deselect_province"):
				game_data.deselect_province()
		elif button == MOUSE_BUTTON_RIGHT:
			if selected_entity != null:
				# Fallback: calculate point on globe surface via sphere intersect
				var sphere_hit = _intersect_ray_sphere(from, ray_normal, Vector3.ZERO, 1000.0)
				if sphere_hit != Vector3.INF:
					print(">>> DEBUG: Right-click in space → using sphere surface point")
					_move_selected(sphere_hit)
					get_viewport().set_input_as_handled()

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
		print(">>> DEBUG MOVE: No selected entity!")
		return
	
	print(">>> DEBUG MOVE: Incoming world_pos = ", world_pos)
	
	var target_pos = world_pos.normalized() * 1002.0
	print(">>> DEBUG MOVE: Normalized target_pos on globe = ", target_pos)
	
	var new_lat = rad_to_deg(asin(target_pos.y / 1002.0))
	var new_lon = rad_to_deg(atan2(target_pos.x, target_pos.z))
	
	print(">>> DEBUG MOVE: Calculated Lat = ", new_lat, "  Lon = ", new_lon)
	print(">>> DEBUG MOVE: Calling move_to on ", selected_entity.entity_name)
	
	selected_entity.move_to(new_lat, new_lon, 6.0)

func _intersect_ray_sphere(ray_origin: Vector3, ray_dir: Vector3, sphere_center: Vector3, sphere_radius: float) -> Vector3:
	var oc = ray_origin - sphere_center
	var a = ray_dir.dot(ray_dir)
	var b = 2.0 * oc.dot(ray_dir)
	var c = oc.dot(oc) - sphere_radius * sphere_radius
	var discriminant = b * b - 4.0 * a * c
	if discriminant < 0: return Vector3.INF
	
	var t = (-b - sqrt(discriminant)) / (2.0 * a)
	if t > 0: return ray_origin + ray_dir * t
	t = (-b + sqrt(discriminant)) / (2.0 * a)
	if t > 0: return ray_origin + ray_dir * t
	return Vector3.INF
