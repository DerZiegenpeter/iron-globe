# scripts/military/FrontlineManager.gd
# Dynamische Frontlinie (stark spürbar durch Einheiten)
extends Node3D
class_name FrontlineManager

@export var frontline_color: Color = Color(0.95, 0.25, 0.15)
@export var frontline_emission: float = 5.0
@export var line_width: float = 2.2
@export var influence_radius: float = 55.0
@export var push_strength: float = 22.0          # Deutlich stärker

var frontlines: Dictionary = {}
var next_id: int = 1

var mesh_instance: MeshInstance3D

var debug_mode: bool = false
var debug_nodes: Array[Node3D] = []


func _ready():
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "FrontlineMesh"
	add_child(mesh_instance)


func _process(_delta):
	_update_frontline_dynamics()
	_rebuild_mesh()


func create_frontline(unit: GroundEntity, target_province_id: int, target_province_name: String = "") -> int:
	if unit.assigned_frontline_id != 0:
		remove_frontline(unit.assigned_frontline_id)

	var game_data = get_node_or_null("/root/GameData")
	if not game_data:
		return 0

	var current_nation = game_data.current_nation
	if current_nation == "GER":
		var owners = game_data.province_to_owner.values()
		if not owners.has("GER") and owners.has("DEU"):
			current_nation = "DEU"

	var player_provinces: Array = []
	for pid in game_data.province_to_owner.keys():
		if game_data.province_to_owner[pid] == current_nation:
			player_provinces.append(pid)

	if player_provinces.is_empty():
		return 0

	var regions = get_node_or_null("/root/World/Regions")
	if not regions or not ("region_polygons" in regions):
		return 0

	var player_coords_set := {}
	for pid in player_provinces:
		for region in regions.region_polygons:
			if region.get("id") != pid and region.get("index", -1) + 1 != pid:
				continue
			for ring in region.get("rings", []):
				for coord in ring:
					var key = "%0.4f_%0.4f" % [coord[0], coord[1]]
					player_coords_set[key] = true

	var all_segments = _get_border_segments(target_province_id)
	if all_segments.is_empty():
		return 0

	var shared_segments: Array = []
	for seg in all_segments:
		var p1 = seg[0]
		var p2 = seg[1]
		var lat1 = rad_to_deg(asin(p1.y / 1002.0))
		var lon1 = rad_to_deg(atan2(p1.x, p1.z))
		var lat2 = rad_to_deg(asin(p2.y / 1002.0))
		var lon2 = rad_to_deg(atan2(p2.x, p2.z))

		var key1 = "%0.4f_%0.4f" % [lon1, lat1]
		var key2 = "%0.4f_%0.4f" % [lon2, lat2]

		if player_coords_set.has(key1) or player_coords_set.has(key2):
			shared_segments.append(seg)

	if shared_segments.is_empty():
		shared_segments = all_segments

	var id = next_id
	next_id += 1

	frontlines[id] = {
		"id": id,
		"nation_a": current_nation,
		"nation_b": target_province_name,
		"base_segments": shared_segments,
		"current_segments": shared_segments.duplicate(true)
	}

	unit.assigned_frontline_id = id
	print("✅ Frontlinie #%d erstellt (dynamisch)" % id)
	return id


func remove_frontline(frontline_id: int):
	if not frontlines.has(frontline_id):
		return
	var data = frontlines[frontline_id]
	var unit = _get_unit_by_id(data.get("owning_unit_id", ""))
	if unit:
		unit.assigned_frontline_id = 0
	frontlines.erase(frontline_id)


# ====================== ECHTE DYNAMIK ======================
func _update_frontline_dynamics():
	var all_units = get_tree().get_nodes_in_group("ground_entities")

	for id in frontlines.keys():
		var data = frontlines[id]
		var new_segments := []

		for seg in data.base_segments:
			var p1 = seg[0]
			var p2 = seg[1]
			var mid = (p1 + p2) * 0.5

			var friendly_force := 0.0
			var enemy_force := 0.0

			for unit in all_units:
				if not is_instance_valid(unit):
					continue

				var dist = mid.distance_to(unit.global_position)
				if dist > influence_radius:
					continue

				var influence = (influence_radius - dist) / influence_radius
				var dir = (unit.global_position - mid).normalized()

				# Hier vereinfacht: GER/DEU = freundlich, alles andere = feindlich
				if unit.nation_code == "GER" or unit.nation_code == "DEU":
					friendly_force += influence * 1.2
				else:
					enemy_force += influence

			var net_force = (friendly_force - enemy_force) * push_strength

			# Push in die Richtung, in die die Mehrheit der Einheiten "drückt"
			var push_dir = mid.normalized()
			if friendly_force > enemy_force * 1.3:
				push_dir = (mid + Vector3(0, 0.1, 0)).normalized()   # leichter Bias nach außen
			elif enemy_force > friendly_force * 1.3:
				push_dir = (mid - Vector3(0, 0.1, 0)).normalized()

			var offset = push_dir * net_force * 0.6

			var np1 = (p1 + offset).normalized() * 1002.0
			var np2 = (p2 + offset).normalized() * 1002.0

			new_segments.append([np1, np2])

		data.current_segments = new_segments


func _rebuild_mesh():
	if not mesh_instance:
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	for id in frontlines:
		for seg in frontlines[id].current_segments:
			_add_ribbon(st, seg[0], seg[1], line_width)

	mesh_instance.mesh = st.commit()

	if mesh_instance.material_override == null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = frontline_color
		mat.emission_enabled = true
		mat.emission = frontline_color * frontline_emission
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.material_override = mat

	if debug_mode:
		_update_debug_visuals()


func _add_ribbon(st: SurfaceTool, p1: Vector3, p2: Vector3, width: float):
	var half = width * 0.5
	var center = (p1 + p2) * 0.5
	var tangent = (p2 - p1).normalized()
	var normal = center.normalized()
	var side = normal.cross(tangent).normalized()
	st.add_vertex(p1 + side * half)
	st.add_vertex(p1 - side * half)
	st.add_vertex(p2 + side * half)
	st.add_vertex(p2 - side * half)


func _get_border_segments(province_id: int) -> Array:
	var regions = get_node_or_null("/root/World/Regions")
	if not regions or not ("region_polygons" in regions):
		return []
	for region in regions.region_polygons:
		if region.get("id") == province_id or region.get("index", -1) + 1 == province_id:
			var rings = region.get("rings", [])
			if rings.is_empty(): return []
			var segments = []
			var ring = rings[0]
			for i in range(ring.size()):
				var p1 = _lat_lon_to_vector3(ring[i][1], ring[i][0], 1002.0)
				var p2 = _lat_lon_to_vector3(ring[(i+1)%ring.size()][1], ring[(i+1)%ring.size()][0], 1002.0)
				segments.append([p1, p2])
			return segments
	return []


func _lat_lon_to_vector3(lat: float, lon: float, radius: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		radius * cos(lat_rad) * sin(lon_rad),
		radius * sin(lat_rad),
		radius * cos(lat_rad) * cos(lon_rad)
	)


func _get_unit_by_id(unit_id: String) -> GroundEntity:
	for unit in get_tree().get_nodes_in_group("ground_entities"):
		if unit.entity_id == unit_id:
			return unit
	return null


func set_debug_mode(enabled: bool):
	debug_mode = enabled
	if not enabled:
		for n in debug_nodes:
			if is_instance_valid(n): n.queue_free()
		debug_nodes.clear()
	_rebuild_mesh()


func _update_debug_visuals():
	for n in debug_nodes:
		if is_instance_valid(n): n.queue_free()
	debug_nodes.clear()
	for id in frontlines:
		var data = frontlines[id]
		for seg in data.current_segments:
			var mid = (seg[0] + seg[1]) * 0.5
			var sphere = MeshInstance3D.new()
			sphere.mesh = SphereMesh.new()
			sphere.mesh.radius = 5.0
			sphere.position = mid
			add_child(sphere)
			debug_nodes.append(sphere)
