extends Node3D

@onready var regions_node: Node3D = get_node("../Regions")
@onready var camera: Camera3D = get_viewport().get_camera_3d()

# Robustere Referenz auf GameData
@onready var game_data = get_node_or_null("/root/GameData")

func _input(event: InputEvent):
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	var ray_origin = camera.project_ray_origin(event.position)
	var ray_dir = camera.project_ray_normal(event.position)
	
	var intersection = intersect_ray_sphere(ray_origin, ray_dir, Vector3.ZERO, regions_node.radius if regions_node else 1000.0)
	if intersection == null:
		print("Nichts getroffen (kein Schnittpunkt mit Sphäre)")
		return
	
	var hit_point = intersection
	var lat_lon = vector3_to_lat_lon(hit_point)
	
	var hit_region = find_region_at(lat_lon)
	if hit_region:
		var rid = str(hit_region.id)
		print("✅ GETROFFEN: ", hit_region.name, " (ID: ", rid, ")")
		
		if game_data:
			print(game_data.get_click_info(rid, hit_region.name))
		else:
			print("   ⚠️ GameData nicht gefunden!")
	else:
		print("Nichts getroffen an Koordinaten: ", lat_lon)

# ==================== HILFSFUNKTIONEN (unverändert) ====================
func intersect_ray_sphere(ray_origin: Vector3, ray_dir: Vector3, sphere_center: Vector3, sphere_radius: float) -> Variant:
	var oc = ray_origin - sphere_center
	var a = ray_dir.dot(ray_dir)
	var b = 2.0 * oc.dot(ray_dir)
	var c = oc.dot(oc) - sphere_radius * sphere_radius
	var discriminant = b * b - 4 * a * c
	if discriminant < 0:
		return null
	var t = (-b - sqrt(discriminant)) / (2.0 * a)
	if t > 0:
		return ray_origin + ray_dir * t
	t = (-b + sqrt(discriminant)) / (2.0 * a)
	if t > 0:
		return ray_origin + ray_dir * t
	return null

func vector3_to_lat_lon(pos: Vector3) -> Dictionary:
	var lat = rad_to_deg(asin(pos.y / pos.length()))
	var lon = rad_to_deg(atan2(pos.x, pos.z))
	return {"lat": lat, "lon": lon}

func find_region_at(lat_lon: Dictionary) -> Variant:
	if not regions_node:
		return null
	var polygons = regions_node.region_polygons
	for region in polygons:
		for ring in region.get("rings", []):
			if point_in_polygon(lat_lon.lat, lat_lon.lon, ring):
				return region
	return null

func point_in_polygon(lat: float, lon: float, ring: Array) -> bool:
	if ring.size() < 3: 
		return false
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
