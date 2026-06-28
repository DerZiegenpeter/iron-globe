# scripts/military/FrontlineManager.gd
# Verbesserte Version mit echter Shared-Border-Erkennung
extends Node3D
class_name FrontlineManager

@export var frontline_color: Color = Color(0.95, 0.25, 0.15)
@export var frontline_emission: float = 5.0
@export var line_width: float = 2.2
@export var push_strength: float = 22.0

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
	_update_frontline_offsets()
	_rebuild_mesh()


# ====================== FRONTLINE ERSTELLEN (mit Shared Border) ======================
func create_frontline(unit: GroundEntity, target_province_id: int, target_province_name: String = "") -> int:
	if unit.assigned_frontline_id != 0:
		remove_frontline(unit.assigned_frontline_id)

	var game_data = get_node_or_null("/root/GameData")
	if not game_data:
		print(">>> [Frontline] GameData nicht gefunden!")
		return 0

	var current_nation = game_data.current_nation

	# 1. Alle Provinzen des Spielers sammeln
	var player_provinces: Array = []
	for pid in game_data.province_to_owner.keys():
		if game_data.province_to_owner[pid] == current_nation:
			player_provinces.append(pid)

	if player_provinces.is_empty():
		print(">>> [Frontline] Keine eigenen Provinzen gefunden!")
		return 0

	# 2. Border-Segmente der angeklickten (feindlichen) Provinz holen
	var all_segments = _get_border_segments(target_province_id)
	if all_segments.is_empty():
		print(">>> [Frontline] Keine Border-Segmente für Provinz", target_province_id)
		return 0

	# 3. Nur die Segmente behalten, die wirklich an eigene Provinzen angrenzen
	var shared_segments: Array = []
	var regions = get_node_or_null("/root/World/Regions")

	for seg in all_segments:
		var mid = (seg[0] + seg[1]) * 0.5
		var is_shared = false

		for player_pid in player_provinces:
			if _is_point_near_player_province(mid, player_pid, regions):
				is_shared = true
				break

		if is_shared:
			shared_segments.append(seg)

	if shared_segments.is_empty():
		print(">>> [Frontline] Keine gemeinsame Grenze zu eigenen Provinzen gefunden. Nehme trotzdem alle Segmente.")
		shared_segments = all_segments   # Fallback

	# 4. Frontline speichern
	var id = next_id
	next_id += 1

	frontlines[id] = {
		"id": id,
		"owning_unit_id": unit.entity_id,
		"target_province_id": target_province_id,
		"target_name": target_province_name,
		"base_segments": shared_segments,
		"current_segments": shared_segments.duplicate(true)
	}

	unit.assigned_frontline_id = id
	print("✅ Frontlinie #%d erstellt (Shared Border) gegen %s" % [id, target_province_name])
	return id


func remove_frontline(frontline_id: int):
	if not frontlines.has(frontline_id):
		return

	var data = frontlines[frontline_id]
	var unit = _get_unit_by_id(data.owning_unit_id)
	if unit:
		unit.assigned_frontline_id = 0

	frontlines.erase(frontline_id)


# ====================== DYNAMISCHER PUSH ======================
func _update_frontline_offsets():
	for id in frontlines.keys():
		var data = frontlines[id]
		var unit = _get_unit_by_id(data.owning_unit_id)

		var new_segments = []
		for seg in data.base_segments:
			var p1 = seg[0]
			var p2 = seg[1]

			if unit and is_instance_valid(unit):
				var mid = (p1 + p2) * 0.5
				var dir = (unit.global_position - mid).normalized()
				var offset = dir * push_strength
				p1 = (p1 + offset).normalized() * 1002.0
				p2 = (p2 + offset).normalized() * 1002.0

			new_segments.append([p1, p2])

		data.current_segments = new_segments


# ====================== HELPER ======================
func _get_border_segments(province_id: int) -> Array:
	var regions = get_node_or_null("/root/World/Regions")
	if not regions or not ("region_polygons" in regions):
		return []

	for region in regions.region_polygons:
		if region.get("id") == province_id or region.get("index", -1) + 1 == province_id:
			var rings = region.get("rings", [])
			if rings.is_empty():
				return []
			var segments = []
			var ring = rings[0]
			for i in range(ring.size()):
				var p1 = _lat_lon_to_vector3(ring[i][1], ring[i][0], 1002.0)
				var p2 = _lat_lon_to_vector3(ring[(i + 1) % ring.size()][1], ring[(i + 1) % ring.size()][0], 1002.0)
				segments.append([p1, p2])
			return segments
	return []


func _is_point_near_player_province(point: Vector3, player_province_id: int, regions: Node) -> bool:
	if not regions or not ("region_polygons" in regions):
		return false

	for region in regions.region_polygons:
		if region.get("id") != player_province_id and region.get("index", -1) + 1 != player_province_id:
			continue

		for ring in region.get("rings", []):
			for coord in ring:
				var player_point = _lat_lon_to_vector3(coord[1], coord[0], 1002.0)
				if point.distance_to(player_point) < 35.0:   # Toleranz (kann angepasst werden)
					return true
	return false


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


# ====================== DEBUG ======================
func set_debug_mode(enabled: bool):
	debug_mode = enabled
	if not enabled:
		for n in debug_nodes:
			if is_instance_valid(n):
				n.queue_free()
		debug_nodes.clear()
	_rebuild_mesh()


func _update_debug_visuals():
	for n in debug_nodes:
		if is_instance_valid(n):
			n.queue_free()
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
