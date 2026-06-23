extends Node3D
class_name GroundEntity

@onready var wire_cube: MeshInstance3D = $WireCube
@onready var name_label: Label3D = get_node_or_null("NameLabel")
@onready var collision_area: Area3D = get_node_or_null("CollisionArea")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionArea/CollisionShape3D")

var entity_id: String = ""
var entity_name: String = ""
var nation_code: String = ""
var entity_type: String = "division"
var is_combat_unit: bool = true

var equipment_readiness: float = 0.85
var manpower: int = 8000
var max_manpower: int = 8000
var organization: float = 80.0
var supply: float = 75.0

const GLOBE_RADIUS := 1002.0
const POSITION_ROTATION_DEGREES := 180.0

var is_selected: bool = false
var raw_data: Dictionary = {}

var movement_speed: float = 0.12
var current_lat: float = 0.0
var current_lon: float = 0.0
var _target_lat: float = 0.0
var _target_lon: float = 0.0
var _has_target: bool = false

var org_bar: MeshInstance3D
var man_bar: MeshInstance3D
var sup_bar: MeshInstance3D

# Kampf
var current_organization: float = 80.0
var max_organization: float = 100.0
var current_manpower: int = 8000
var initiative: float = 0.0
var in_combat: bool = false
var current_enemy: GroundEntity = null
var combat_line: MeshInstance3D = null
var is_attacker: bool = false

var battalions: Array = []
var required_equipment: Dictionary = {}
var missing_equipment: Dictionary = {}
var soft_attack: float = 0.0
var hard_attack: float = 0.0
var defense: float = 0.0
var breakthrough: float = 0.0
var supply_consumption: float = 0.0
var experience: float = 40.0
var equipment_fulfillment: float = 0.85


func _ready():
	if has_meta("unit_data"):
		var data = get_meta("unit_data")
		entity_id = data.get("id", name)
		entity_name = data.get("name", entity_id)
		entity_type = data.get("type", get_meta("unit_type", "division"))
		nation_code = get_meta("nation_code", "GER")
		raw_data = data

		if data.has("position") and data.position is Array and data.position.size() >= 3:
			var raw_pos = Vector3(data.position[0], data.position[1], data.position[2])
			var dir = raw_pos.normalized()
			if POSITION_ROTATION_DEGREES != 0.0:
				dir = dir.rotated(Vector3.UP, deg_to_rad(POSITION_ROTATION_DEGREES))
			global_position = dir * GLOBE_RADIUS

		manpower = data.get("manpower", manpower)
		max_manpower = data.get("max_manpower", max_manpower)
		organization = data.get("organization", organization)
		supply = data.get("supply", 75.0)
		equipment_readiness = data.get("equipment_readiness", equipment_readiness)

	current_organization = organization
	current_manpower = manpower

	if name_label:
		name_label.text = entity_name
		name_label.font_size = 60
		name_label.position = Vector3(0, 3.8, 0.6)
		name_label.modulate = Color(0.95, 0.97, 1.0, 0.95)
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	if collision_area:
		collision_area.visible = false
		collision_area.monitoring = true
		collision_area.monitorable = true
	if collision_shape:
		collision_shape.visible = false

	_setup_bars_side_by_side()
	_apply_scale_by_type()
	create_wireframe_cube()

	if is_combat_unit and raw_data.has("battalions") and raw_data.battalions is Array:
		_aggregate_from_battalions(raw_data.battalions)

	update_bars()
	_apply_orientation()
	add_to_group("ground_entities")


func _load_battalion_templates() -> Dictionary:
	var path = "res://data/battalion_types.json"
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return json.data


func _aggregate_from_battalions(bn_list: Array):
	var total_man = 0
	var total_max_man = 0
	var total_org = 0.0
	var total_exp = 0.0
	var total_init = 0.0
	var count = 0
	var total_soft = 0.0
	var total_hard = 0.0
	var total_def = 0.0
	var total_break = 0.0
	var total_supply = 0.0

	required_equipment.clear()
	battalions.clear()
	missing_equipment.clear()

	var bn_templates = _load_battalion_templates()

	for bn_data in bn_list:
		if not bn_data is Dictionary: continue
		var bn_type = bn_data.get("type", "infantry")
		var template = bn_templates.get(bn_type, {})
		if template.is_empty(): continue

		var resolved = bn_data.duplicate(true)
		resolved["template"] = template
		resolved["display_type"] = template.get("display_name", bn_type)
		battalions.append(resolved)

		total_man += bn_data.get("manpower", template.get("manpower", 500))
		total_max_man += bn_data.get("max_manpower", total_man)
		total_org += bn_data.get("organization", template.get("organization", 80))
		total_exp += bn_data.get("experience", 40)
		total_init += template.get("initiative", 6)
		count += 1

		total_soft += template.get("soft_attack", 0)
		total_hard += template.get("hard_attack", 0)
		total_def += template.get("defense", 0)
		total_break += template.get("breakthrough", 0)
		total_supply += template.get("supply_consumption", 0)

		var eq_req = template.get("equipment_requirements", {})
		for eq_id in eq_req:
			required_equipment[eq_id] = required_equipment.get(eq_id, 0) + eq_req[eq_id]

	if count > 0:
		manpower = total_man
		max_manpower = total_max_man
		organization = total_org / count
		experience = total_exp / count
		initiative = total_init / count
		soft_attack = total_soft
		hard_attack = total_hard
		defense = total_def
		breakthrough = total_break
		supply_consumption = total_supply
		equipment_fulfillment = raw_data.get("equipment_readiness", 0.85)
		equipment_readiness = equipment_fulfillment

		for eq_id in required_equipment:
			missing_equipment[eq_id] = int(required_equipment[eq_id] * (1.0 - equipment_fulfillment))

	current_organization = organization
	current_manpower = manpower


func _setup_bars_side_by_side():
	org_bar = get_node_or_null("Bars/OrgBar")
	man_bar = get_node_or_null("Bars/ManBar")
	sup_bar = get_node_or_null("Bars/SupBar")

	var bars = [org_bar, man_bar, sup_bar]
	var colors = [Color(0.3, 0.75, 1.0), Color(0.35, 0.9, 0.45), Color(0.95, 0.75, 0.2)]

	for i in range(bars.size()):
		var bar = bars[i]
		if not bar: continue
		bar.position = Vector3(2.6 + i * 0.85, 0.8, 0.5)
		bar.rotation_degrees = Vector3(-90, 0, 0)
		if not bar.material_override:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			mat.emission_enabled = true
			mat.emission = colors[i] * 6.0
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bar.material_override = mat


func _apply_scale_by_type():
	var visual_scale := 1.0
	match entity_type:
		"high_command": visual_scale = 2.8
		"army_group":   visual_scale = 2.4
		"army":         visual_scale = 2.0
		"corps":        visual_scale = 1.6
		"brigade":      visual_scale = 1.1
		_:              visual_scale = 1.3

	if wire_cube:
		wire_cube.scale = Vector3(visual_scale, visual_scale, visual_scale)

	if collision_shape and collision_shape.shape is BoxShape3D:
		var buffer := 1.1
		collision_shape.shape.size = Vector3(visual_scale * 2.0 + buffer, visual_scale * 2.0 + buffer, visual_scale * 2.0 + buffer)


func create_wireframe_cube():
	if not wire_cube: return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var s := 1.0
	var v := [
		Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, s, -s), Vector3(-s, s, -s),
		Vector3(-s, -s, s), Vector3(s, -s, s), Vector3(s, s, s), Vector3(-s, s, s)
	]
	var edges := [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
	for e in edges:
		st.add_vertex(v[e[0]])
		st.add_vertex(v[e[1]])
	wire_cube.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.82, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.75, 1.0) * 5.5
	wire_cube.material_override = mat


func update_bars():
	if not org_bar or not man_bar or not sup_bar: return
	_set_vertical_bar(org_bar, clamp(current_organization / 100.0, 0.0, 1.0), Color(0.3, 0.75, 1.0))
	_set_vertical_bar(man_bar, clamp(float(current_manpower) / float(max_manpower), 0.0, 1.0), Color(0.35, 0.9, 0.45))
	_set_vertical_bar(sup_bar, clamp(equipment_fulfillment, 0.0, 1.0), Color(0.95, 0.75, 0.2))


func _set_vertical_bar(bar: MeshInstance3D, percent: float, color: Color):
	if not bar or not bar.material_override: return
	bar.material_override.albedo_color = color
	bar.material_override.emission = color * 5.5
	bar.scale = Vector3(0.7, max(percent, 0.1), 0.7)


func _apply_orientation():
	if global_position.length() > 10.0:
		var normal = global_position.normalized()
		look_at(global_position + normal * 50.0, Vector3.UP)


func select():
	is_selected = true
	if wire_cube and wire_cube.material_override:
		wire_cube.material_override.emission = Color(0.6, 0.95, 1.0) * 9.0


func deselect():
	is_selected = false
	if wire_cube and wire_cube.material_override:
		wire_cube.material_override.emission = Color(0.35, 0.75, 1.0) * 5.5


func move_to(new_lat: float, new_lon: float):
	_target_lat = new_lat
	_target_lon = new_lon
	_has_target = true


func _process(delta: float):
	# === BEWEGUNG MIT SANFTER BESCHLEUNIGUNG + VERLANGSAMUNG ===
	if _has_target:
		var tm = get_node_or_null("/root/TimeManager")
		if tm and not tm.paused and tm.speed > 0:
			var sim_speed = float(tm.speed)
			var base_speed = movement_speed * sim_speed

			# Sanfte Beschleunigung am Start + sanfte Verlangsamung am Ziel
			var progress = 1.0
			var current_pos = global_position.normalized()
			var target_pos = _lat_lon_to_vector3(_target_lat, _target_lon, GLOBE_RADIUS).normalized()
			var total_angle = acos(clampf(current_pos.dot(target_pos), -1.0, 1.0))

			if total_angle > 0.01:
				progress = clamp(1.0 - (total_angle / (total_angle + 1.2)), 0.25, 1.0)

			var move_distance = (base_speed * progress * delta) / GLOBE_RADIUS * (180.0 / PI)

			var angle_to_target = acos(clampf(current_pos.dot(target_pos), -1.0, 1.0))

			if angle_to_target <= move_distance or angle_to_target < 0.001:
				global_position = target_pos * GLOBE_RADIUS
				current_lat = _target_lat
				current_lon = _target_lon
				_has_target = false
				_on_arrival()
			else:
				var axis = current_pos.cross(target_pos).normalized()
				if axis.length() < 0.001:
					axis = Vector3.UP
				var partial_quat = Quaternion(axis, move_distance)
				var new_dir = partial_quat * current_pos
				global_position = new_dir * GLOBE_RADIUS

				var mag = global_position.length()
				current_lat = rad_to_deg(asin(global_position.y / mag))
				current_lon = rad_to_deg(atan2(global_position.x, global_position.z))

				_apply_orientation()

	# Rote Linie live aktualisieren
	if in_combat and current_enemy and combat_line and is_instance_valid(combat_line):
		_update_combat_line()

	if is_combat_unit:
		_resolve_unit_collisions(delta)


func _update_combat_line():
	if not combat_line or not current_enemy: return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.add_vertex(Vector3.ZERO)
	st.add_vertex(current_enemy.global_position - global_position)
	combat_line.mesh = st.commit()
	combat_line.global_position = global_position


func _on_arrival():
	print("Einheit angekommen: ", entity_name)


func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)


func _resolve_unit_collisions(delta: float):
	if not collision_shape: return
	var overlaps = collision_area.get_overlapping_areas() if collision_area else []

	for oa in overlaps:
		var other = oa.get_parent()
		if not (other is GroundEntity) or other == self or not other.is_combat_unit:
			continue

		if not is_at_war_with(other.nation_code):
			continue

		var dist = global_position.distance_to(other.global_position)

		# Kampf starten (ohne Positionsveränderung!)
		if not in_combat and dist < 35.0:
			start_combat(other)
			if other and not other.in_combat:
				other.start_combat(self)
			continue

		# Sanftes Festhalten im Kampf (nur auseinander schieben wenn zu nah)
		if in_combat and current_enemy == other:
			var min_dist = 26.0

			if dist < min_dist:
				var push_dir = (global_position - other.global_position).normalized()
				var push_force = 8.0 * delta * _get_push_multiplier(other)

				if _get_strength() > other._get_strength():
					other.global_position += push_dir * push_force
				else:
					global_position += push_dir * -push_force

			global_position = global_position.normalized() * GLOBE_RADIUS
			other.global_position = other.global_position.normalized() * GLOBE_RADIUS
			continue

		# Normales Ausweichen
		if dist < 14.0:
			var push = (global_position - other.global_position).normalized()
			global_position += push * 10.0 * delta
			global_position = global_position.normalized() * GLOBE_RADIUS


func _get_push_multiplier(other: GroundEntity) -> float:
	var my_str = _get_strength()
	var other_str = other._get_strength()
	if other_str <= 0: return 2.0
	return clamp(my_str / other_str, 0.6, 2.3)


func _get_strength() -> float:
	return float(current_manpower) * clamp(current_organization / 100.0, 0.3, 1.4)


# ====================== KAMPF METHODEN ======================

func is_at_war_with(other_nation: String) -> bool:
	var diplomacy = get_node_or_null("/root/DiplomacyManager")
	if diplomacy and diplomacy.has_method("is_at_war"):
		return diplomacy.is_at_war(nation_code, other_nation)
	return nation_code != other_nation and ((nation_code == "GER" and other_nation == "POL") or (nation_code == "POL" and other_nation == "GER"))


func start_combat(enemy: GroundEntity, attacker_side: bool = false):
	if in_combat or enemy == self: return
	in_combat = true
	current_enemy = enemy
	is_attacker = attacker_side
	_create_combat_line(enemy)


func end_combat():
	in_combat = false
	current_enemy = null
	is_attacker = false
	if combat_line and is_instance_valid(combat_line):
		combat_line.queue_free()
	combat_line = null


func _create_combat_line(enemy: GroundEntity):
	if combat_line and is_instance_valid(combat_line):
		combat_line.queue_free()

	combat_line = MeshInstance3D.new()
	get_tree().current_scene.add_child(combat_line)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.add_vertex(Vector3.ZERO)
	st.add_vertex(enemy.global_position - global_position)
	combat_line.mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2) * 5.0
	combat_line.material_override = mat
	combat_line.global_position = global_position


func take_combat_damage(soft_dmg: float, hard_dmg: float, org_dmg: float):
	current_manpower = max(0, current_manpower - int(soft_dmg + hard_dmg * 0.65))
	current_organization = max(0.0, current_organization - org_dmg)
	update_bars()
	if current_organization < 20.0:
		end_combat()


func gain_experience(amount: float):
	experience = min(100.0, experience + amount)
