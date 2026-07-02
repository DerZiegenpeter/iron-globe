extends Node

var selected_entity: Node = null

var frontline_placement_mode: bool = false
var pending_frontline_unit: GroundEntity = null


func _input(event):
	# ====================== FRONTLINE PLACEMENT ======================
	if frontline_placement_mode and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()

		if pending_frontline_unit == null:
			frontline_placement_mode = false
			return

		var regions = get_node_or_null("/root/World/Regions")
		if not regions or not ("region_polygons" in regions):
			frontline_placement_mode = false
			return

		var camera = get_viewport().get_camera_3d()
		if not camera: return

		var from = camera.project_ray_origin(event.position)
		var ray_dir = camera.project_ray_normal(event.position)
		var hit_point = _intersect_ray_sphere(from, ray_dir, Vector3.ZERO, 1000.0)

		if hit_point == Vector3.INF:
			print("[Frontline] Kein Treffer auf Globe")
			frontline_placement_mode = false
			return

		var lat_lon = _vector3_to_lat_lon(hit_point)

		var hit_region = null
		for region in regions.region_polygons:
			for ring in region.get("rings", []):
				if _point_in_polygon(lat_lon.lat, lat_lon.lon, ring):
					hit_region = region
					break
			if hit_region: break

		if hit_region == null or hit_region.is_empty():
			print("[Frontline] Keine Region gefunden")
			frontline_placement_mode = false
			return

		var province_id = hit_region.get("id", hit_region.get("index", 0) + 1)
		var province_name = hit_region.get("name", "Unknown")

		var fl_manager = get_node_or_null("/root/World/FrontlineManager")
		if fl_manager and fl_manager.has_method("create_frontline"):
			var result = fl_manager.create_frontline(pending_frontline_unit, province_id, province_name)
			if result == 0:
				print("❌ [Frontline] Platzierung fehlgeschlagen - keine gültige Nachbarprovinz!")
			else:
				print("✅ [Frontline] Frontlinie erfolgreich platziert!")
		else:
			print("[Frontline] FrontlineManager nicht gefunden")

		frontline_placement_mode = false
		pending_frontline_unit = null
		return

	# ====================== F-Taste ======================
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if selected_entity is GroundEntity:
			start_frontline_placement(selected_entity)
		else:
			print(">>> [F] Bitte zuerst eine Einheit auswählen")
		return


func _unhandled_input(event):
	if frontline_placement_mode: return

	if not (event is InputEventMouseButton and event.pressed): return

	var button = event.button_index
	var camera = get_viewport().get_camera_3d()
	if not camera: return

	var from = camera.project_ray_origin(event.position)
	var ray_dir = camera.project_ray_normal(event.position)

	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, from + ray_dir * 8000)
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
		if selected_entity == null: return

		var target_world_pos: Vector3
		if result:
			target_world_pos = result.position
		else:
			var hit_point = _intersect_ray_sphere(from, ray_dir, Vector3.ZERO, 1000.0)
			if hit_point == Vector3.INF: return
			target_world_pos = hit_point

		_issue_move_order(target_world_pos)


func start_frontline_placement(unit: GroundEntity):
	frontline_placement_mode = true
	pending_frontline_unit = unit
	print("🟥 Frontline Placement Mode aktiviert für: ", unit.entity_name)
	print("Klicke jetzt auf eine direkte Nachbarprovinz von Deutschland!")


func _select(entity: Node):
	_deselect()
	selected_entity = entity
	if entity.has_method("select"):
		entity.select()

	var game_data = get_node_or_null("/root/GameData")
	if game_data:
		game_data.unit_selected.emit(entity)


func _deselect():
	if selected_entity:
		var gd = get_node_or_null("/root/GameData")
		if gd:
			gd.unit_deselected.emit()
		if selected_entity.has_method("deselect"):
			selected_entity.deselect()
		selected_entity = null


func _issue_move_order(world_pos: Vector3):
	if selected_entity == null: return
	if selected_entity.has_method("move_to"):
		var target_pos = world_pos.normalized() * 1002.0
		var new_lat = rad_to_deg(asin(target_pos.y / 1002.0))
		var new_lon = rad_to_deg(atan2(target_pos.x, target_pos.z))
		selected_entity.move_to(new_lat, new_lon)


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


func _vector3_to_lat_lon(pos: Vector3) -> Dictionary:
	var mag = pos.length()
	if mag == 0: return {"lat": 0.0, "lon": 0.0}
	var lat = rad_to_deg(asin(pos.y / mag))
	var lon = rad_to_deg(atan2(pos.x, pos.z))
	return {"lat": lat, "lon": lon}


func _point_in_polygon(lat: float, lon: float, ring: Array) -> bool:
	if ring.size() < 3: return false
	var inside = false
	var n = ring.size()
	var j = n - 1
	for i in range(n):
		var xi = ring[i][0]
		var yi = ring[i][1]
		var xj = ring[j][0]
		var yj = ring[j][1]
		if ((yi > lat) != (yj > lat)) and (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi):
			inside = !inside
		j = i
	return inside
