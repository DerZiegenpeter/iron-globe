extends Node3D

@onready var regions_node: Node3D = get_node_or_null("../Regions")
@onready var game_data: Node = get_node_or_null("/root/GameData")
@onready var input_manager: Node = get_node_or_null("/root/InputManager")

func _input(event: InputEvent):
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	if get_viewport().is_input_handled():
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var ray_origin = camera.project_ray_origin(event.position)
	var ray_dir = camera.project_ray_normal(event.position)
	
	# === PRIORITÄT: Military Entity? Dann ClickHandler überspringen (InputManager übernimmt) ===
	var space_state = get_viewport().get_world_3d().direct_space_state
	var phys_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 5000.0)
	phys_query.collide_with_areas = true
	phys_query.collision_mask = 1  # Nur Entities (Layer 1)
	var phys_result = space_state.intersect_ray(phys_query)
	if phys_result:
		var hit = phys_result.collider.get_parent()
		while hit and not (hit is GroundEntity):
			hit = hit.get_parent()
		if hit is GroundEntity:
			# Entity-Klick → InputManager handhabt Select/Move, wir überspringen State-Logik
			get_viewport().set_input_as_handled()
			return
	
	# === STATE / WASSER Klick via Sphere + Point-in-Polygon ===
	var hit_point = intersect_ray_sphere(ray_origin, ray_dir, Vector3.ZERO, 1000.0)
	if hit_point == Vector3.INF:
		deselect_current()
		get_viewport().set_input_as_handled()
		return
	
	var lat_lon = vector3_to_lat_lon(hit_point)
	var hit_region = find_region_at(lat_lon)
	
	if hit_region != null and not hit_region.is_empty():
		handle_click(hit_region)
	else:
		deselect_current()
	
	get_viewport().set_input_as_handled()

func handle_click(hit_region: Dictionary):
	var province_id = hit_region.get("index", 0) as int + 1
	var region_name = hit_region.get("name", "Unbekannt")
	
	# Military deselecten falls vorhanden
	if input_manager and input_manager.has_method("_deselect"):
		input_manager._deselect()
	
	if game_data and game_data.has_method("select_province"):
		var info = game_data.get_province_info(province_id, region_name)
		game_data.select_province(province_id, region_name, info)
	else:
		print("GETROFFEN: ", region_name, " (ID: ", province_id, ")")
		if game_data and game_data.has_method("get_province_info"):
			print(game_data.get_province_info(province_id, region_name))

func deselect_current():
	if game_data and game_data.has_method("deselect_province"):
		game_data.deselect_province()

# ====================== HILFSFUNKTIONEN ======================

func intersect_ray_sphere(ray_origin: Vector3, ray_dir: Vector3, sphere_center: Vector3, sphere_radius: float) -> Vector3:
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

func vector3_to_lat_lon(pos: Vector3) -> Dictionary:
	var mag = pos.length()
	if mag == 0: return {"lat": 0.0, "lon": 0.0}
	var lat = rad_to_deg(asin(pos.y / mag))
	var lon = rad_to_deg(atan2(pos.x, pos.z))
	return {"lat": lat, "lon": lon}

func find_region_at(lat_lon: Dictionary) -> Dictionary:
	if not regions_node or not ("region_polygons" in regions_node):
		return {}
	
	var polygons = regions_node.region_polygons
	for region in polygons:
		for ring in region.get("rings", []):
			if point_in_polygon(lat_lon.lat, lat_lon.lon, ring):
				return region
	return {}

func point_in_polygon(lat: float, lon: float, ring: Array) -> bool:
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
