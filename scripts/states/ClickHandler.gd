# ClickHandler.gd
extends Node3D

@onready var regions_node: Node3D = get_node_or_null("../Regions")
@onready var camera: Camera3D = get_viewport().get_camera_3d()

@onready var game_data: Node = get_node_or_null("/root/GameData")

func _input(event: InputEvent):
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	var ray_origin = camera.project_ray_origin(event.position)
	var ray_dir = camera.project_ray_normal(event.position)
	
	var hit_point = intersect_ray_sphere(ray_origin, ray_dir, Vector3.ZERO, regions_node.radius if regions_node else 1000.0)
	if hit_point == null:
		print("Nichts getroffen")
		return
	
	var lat_lon = vector3_to_lat_lon(hit_point)
	var hit_region = find_region_at(lat_lon)
	
	if hit_region:
		var raw_id = hit_region.get("id")          # Kann "IND" oder Zahl sein
		var region_name = hit_region.get("name", "Unbekannt")
		
		print("✅ GETROFFEN: ", region_name, " | Raw ID: ", raw_id)
		
		if game_data and game_data.has_method("get_province_info_by_code"):
			var info = game_data.get_province_info_by_code(str(raw_id))
			print("   Name: ", region_name)
			print("   Besitzer: ", info.get("owner", "Unbekannt"), " (", info.get("owner_code", "NEU"), ")")
			print("   Controller: ", info.get("controller_name", "Unbekannt"), " (", info.get("controller", "NEU"), ")")
		else:
			print("   ⚠️ GameData nicht gefunden!")
	else:
		print("Keine Region gefunden")

# ==================== HILFSFUNKTIONEN ====================

func intersect_ray_sphere(ray_origin: Vector3, ray_dir: Vector3, sphere_center: Vector3, sphere_radius: float) -> Variant:
	var oc = ray_origin - sphere_center
	var a = ray_dir.dot(ray_dir)
	var b = 2.0 * oc.dot(ray_dir)
	var c = oc.dot(oc) - sphere_radius * sphere_radius
	var discriminant = b * b - 4 * a * c
	if discriminant < 0: return null
	var t1 = (-b - sqrt(discriminant)) / (2.0 * a)
	var t2 = (-b + sqrt(discriminant)) / (2.0 * a)
	if t1 > 0: return ray_origin + ray_dir * t1
	if t2 > 0: return ray_origin + ray_dir * t2
	return null

func vector3_to_lat_lon(pos: Vector3) -> Dictionary:
	var normalized = pos.normalized()
	var lat = rad_to_deg(asin(normalized.y))
	var lon = rad_to_deg(atan2(normalized.x, normalized.z))
	return {"lat": lat, "lon": lon}

func find_region_at(lat_lon: Dictionary) -> Variant:
	if not regions_node: return null
	if "region_polygons" in regions_node:
		for region in regions_node.region_polygons:
			for ring in region.get("rings", []):
				if point_in_polygon(lat_lon.lat, lat_lon.lon, ring):
					return region
	return null

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
