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
	var ray_dir = camera.project_ray_normal(event.position)
	var to = from + ray_dir * 8000

	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF

	var result = space_state.intersect_ray(query)

	if button == MOUSE_BUTTON_LEFT:
		if result:
			var hit = result.collider.get_parent()
			while hit and not hit is GroundEntity:
				hit = hit.get_parent()
			if hit is GroundEntity:
				_select(hit)
		else:
			_deselect()

	elif button == MOUSE_BUTTON_RIGHT:
		if selected_entity == null:
			return  # Kein Befehl ohne Auswahl

		var target_world_pos: Vector3
		if result:
			target_world_pos = result.position
		else:
			# Fallback: mathematischer Sphere-Intersect (wie in ClickHandler)
			var hit_point = _intersect_ray_sphere(from, ray_dir, Vector3.ZERO, 1000.0)
			if hit_point == Vector3.INF:
				return
			target_world_pos = hit_point

		_issue_move_order(target_world_pos)


func _select(entity: GroundEntity):
	_deselect()
	selected_entity = entity
	entity.select()


func _deselect():
	if selected_entity:
		selected_entity.deselect()
		selected_entity = null


func _issue_move_order(world_pos: Vector3):
	if selected_entity == null:
		return

	var target_pos = world_pos.normalized() * 1002.0
	var new_lat = rad_to_deg(asin(target_pos.y / 1002.0))
	var new_lon = rad_to_deg(atan2(target_pos.x, target_pos.z))

	selected_entity.move_to(new_lat, new_lon)


# ====================== HELPER (aus ClickHandler übernommen) ======================

func _intersect_ray_sphere(ray_origin: Vector3, ray_dir: Vector3, sphere_center: Vector3, sphere_radius: float) -> Vector3:
	var oc = ray_origin - sphere_center
	var a = ray_dir.dot(ray_dir)
	var b = 2.0 * oc.dot(ray_dir)
	var c = oc.dot(oc) - sphere_radius * sphere_radius
	var discriminant = b * b - 4.0 * a * c
	if discriminant < 0:
		return Vector3.INF

	var t = (-b - sqrt(discriminant)) / (2.0 * a)
	if t > 0:
		return ray_origin + ray_dir * t
	t = (-b + sqrt(discriminant)) / (2.0 * a)
	if t > 0:
		return ray_origin + ray_dir * t
	return Vector3.INF
