# scripts/military/FrontlineManager.gd
# Stark verbesserte Dynamik-Version
extends Node3D
class_name FrontlineManager

@export var frontline_color: Color = Color(0.95, 0.2, 0.15)
@export var frontline_emission: float = 7.5
@export var line_width: float = 4.2
@export var influence_radius: float = 95.0      # größer = Front reagiert früher
@export var push_strength: float = 65.0          # deutlich stärker

var frontlines: Dictionary = {}
var next_id: int = 1

var mesh_instance: MeshInstance3D


func _ready():
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "FrontlineMesh"
	add_child(mesh_instance)

	var diplomacy = get_node_or_null("/root/DiplomacyManager")
	if diplomacy and diplomacy.has_signal("war_declared"):
		diplomacy.war_declared.connect(_on_war_declared)

	call_deferred("_create_initial_frontlines")
	print("=== FrontlineManager (starke Dynamik) gestartet ===")


func _create_initial_frontlines():
	var diplomacy = get_node_or_null("/root/DiplomacyManager")
	if not diplomacy: return

	for nation_a in diplomacy.wars.keys():
		for nation_b in diplomacy.wars[nation_a]:
			create_frontlines_for_war(nation_a, nation_b)


func _on_war_declared(nation_a: String, nation_b: String):
	create_frontlines_for_war(nation_a, nation_b)


func create_frontlines_for_war(nation_a: String, nation_b: String):
	var game_data = get_node_or_null("/root/GameData")
	if not game_data: return

	var player_nation = _get_player_nation_code(game_data)
	if player_nation not in [nation_a, nation_b]:
		return

	var enemy_nation = nation_b if nation_a == player_nation else nation_a

	var enemy_provinces: Array = []
	for pid in game_data.province_to_owner.keys():
		if game_data.province_to_owner[pid] == enemy_nation:
			enemy_provinces.append(pid)

	for enemy_pid in enemy_provinces:
		if is_direct_neighbor(enemy_pid, player_nation):
			var unit = _find_any_player_unit()
			if unit:
				create_frontline(unit, enemy_pid)


func _get_player_nation_code(game_data) -> String:
	var code = game_data.current_nation
	if code == "GER" and game_data.nations.has("DEU"):
		return "DEU"
	return code


func _find_any_player_unit() -> GroundEntity:
	var units = get_tree().get_nodes_in_group("ground_entities")
	for u in units:
		if u.nation_code in ["DEU", "GER"]:
			return u
	return null


func create_frontline(unit: GroundEntity, target_province_id: int) -> int:
	if not unit or not is_instance_valid(unit):
		return 0

	var game_data = get_node_or_null("/root/GameData")
	if not game_data: return 0

	var player_nation = _get_player_nation_code(game_data)

	if not is_direct_neighbor(target_province_id, player_nation):
		print("❌ Keine direkte Grenze zu %s" % player_nation)
		return 0

	if unit.assigned_frontline_id != 0:
		remove_frontline(unit.assigned_frontline_id)

	var shared_segments = _get_shared_border_segments(target_province_id, player_nation)
	if shared_segments.is_empty():
		return 0

	var id = next_id
	next_id += 1

	frontlines[id] = {
		"id": id,
		"nation_a": player_nation,
		"target_province_id": target_province_id,
		"base_segments": shared_segments,
		"current_segments": shared_segments.duplicate(true),
		"owning_unit_id": unit.entity_id
	}

	unit.assigned_frontline_id = id
	print("✅ Frontlinie #%d erstellt" % id)
	return id


func is_direct_neighbor(target_province_id: int, player_nation: String) -> bool:
	return _get_shared_border_segments(target_province_id, player_nation).size() > 0


func _get_shared_border_segments(target_province_id: int, player_nation: String) -> Array:
	var game_data = get_node_or_null("/root/GameData")
	var regions = get_node_or_null("/root/World/Regions")
	if not game_data or not regions: return []

	var player_provinces: Array = []
	for pid in game_data.province_to_owner.keys():
		if game_data.province_to_owner[pid] == player_nation:
			player_provinces.append(pid)

	var target_segments = _get_border_segments(target_province_id)
	if target_segments.is_empty(): return []

	var shared := []
	for seg in target_segments:
		var p1 = seg[0]
		var p2 = seg[1]

		for player_pid in player_provinces:
			for ps in _get_border_segments(player_pid):
				if (p1.distance_to(ps[0]) < 14.0 or p1.distance_to(ps[1]) < 14.0 or
					p2.distance_to(ps[0]) < 14.0 or p2.distance_to(ps[1]) < 14.0):
					shared.append(seg)
					break
	return shared


func remove_frontline(frontline_id: int):
	if not frontlines.has(frontline_id): return
	var data = frontlines[frontline_id]
	if data.has("owning_unit_id"):
		var unit = _get_unit_by_id(data["owning_unit_id"])
		if unit: unit.assigned_frontline_id = 0
	frontlines.erase(frontline_id)


# ====================== DYNAMIK (stark verbessert) ======================
func _update_frontline_dynamics():
	if frontlines.is_empty(): return

	var all_units = get_tree().get_nodes_in_group("ground_entities")
	if all_units.is_empty(): return

	for id in frontlines.keys():
		var data = frontlines[id]
		var new_segments := []
		var nation_a = data.get("nation_a", "DEU")

		for seg in data.base_segments:
			var p1 = seg[0]
			var p2 = seg[1]
			var mid = (p1 + p2) * 0.5

			var force_a := 0.0
			var force_b := 0.0

			for unit in all_units:
				if not is_instance_valid(unit): continue
				var dist = mid.distance_to(unit.global_position)
				if dist > influence_radius: continue

				var influence = (influence_radius - dist) / influence_radius

				if unit.nation_code in [nation_a, "GER", "DEU"]:
					force_a += influence * 3.0          # Freund pushen stärker
				else:
					force_b += influence * 2.8          # Feind pushen

			var net_force = (force_a - force_b) * push_strength

			var push_dir = mid.normalized()
			if force_a > force_b * 1.1:
				push_dir = (mid + Vector3(0, 0.25, 0)).normalized()
			elif force_b > force_a * 1.1:
				push_dir = (mid - Vector3(0, 0.25, 0)).normalized()

			var offset = push_dir * net_force * 1.1
			var np1 = (p1 + offset).normalized() * 1002.0
			var np2 = (p2 + offset).normalized() * 1002.0

			new_segments.append([np1, np2])

		data.current_segments = new_segments


func _rebuild_mesh():
	if not mesh_instance: return

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
		mesh_instance.material_override = mat


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
	if not regions: return []
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


func _process(_delta):
	_update_frontline_dynamics()
	_rebuild_mesh()
