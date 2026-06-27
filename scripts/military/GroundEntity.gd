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

# ====================== ORIGINAL BEWEGUNG ======================
var movement_speed: float = 0.12
var current_lat: float = 0.0
var current_lon: float = 0.0
var _target_lat: float = 0.0
var _target_lon: float = 0.0
var _has_target: bool = false

# ====================== ENGAGEMENT ======================
var engaged_with: GroundEntity = null
var is_attacker_in_engagement: bool = false
var combat_dot: MeshInstance3D = null

var in_combat: bool = false
var current_enemy: GroundEntity = null
var is_attacker: bool = false

var org_bar: MeshInstance3D
var man_bar: MeshInstance3D
var sup_bar: MeshInstance3D

var current_organization: float = 80.0
var max_organization: float = 100.0
var current_manpower: int = 8000
var initiative: float = 0.0
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


# ====================== BEWEGUNG (mit Fix für kurze Strecken) ======================

func move_to(new_lat: float, new_lon: float):
	_target_lat = new_lat
	_target_lon = new_lon
	_has_target = true


func _process(delta: float):
	if _has_target:
		var tm = get_node_or_null("/root/TimeManager")
		if tm and not tm.paused and tm.speed > 0:
			var sim_speed = float(tm.speed)
			var base_speed = movement_speed * sim_speed

			var current_pos = global_position.normalized()
			var target_pos = _lat_lon_to_vector3(_target_lat, _target_lon, GLOBE_RADIUS).normalized()
			var total_angle = acos(clampf(current_pos.dot(target_pos), -1.0, 1.0))

			var progress = 1.0
			if total_angle > 0.01:
				progress = clamp(1.0 - (total_angle / (total_angle + 1.2)), 0.05, 1.0)

			var move_distance = (base_speed * progress * delta) / GLOBE_RADIUS * (180.0 / PI)
			var angle_to_target = acos(clampf(current_pos.dot(target_pos), -1.0, 1.0))

			# === FIX FÜR KURZE STRECKE: Immer weich landen ===
			if angle_to_target < 0.08:          # bei kurzen Wegen immer soft
				global_position = global_position.lerp(target_pos * GLOBE_RADIUS, 10.0 * delta)
				if global_position.distance_to(target_pos * GLOBE_RADIUS) < 0.25:
					global_position = target_pos * GLOBE_RADIUS
					current_lat = _target_lat
					current_lon = _target_lon
					_has_target = false
					_on_arrival()
			elif angle_to_target <= move_distance:
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

	# Engagement
	if engaged_with and is_instance_valid(engaged_with):
		_update_engagement_forces(delta)
	else:
		_resolve_unit_collisions(delta)


# ====================== ENGAGEMENT ======================

func start_engagement(enemy: GroundEntity, am_i_attacker: bool = false):
	if engaged_with == enemy or enemy == self: return
	end_engagement()

	engaged_with = enemy
	is_attacker_in_engagement = am_i_attacker
	in_combat = true
	current_enemy = enemy
	is_attacker = am_i_attacker

	_create_combat_dot()


func end_engagement():
	if engaged_with and is_instance_valid(engaged_with):
		if engaged_with.engaged_with == self:
			engaged_with.end_engagement()

	engaged_with = null
	is_attacker_in_engagement = false
	in_combat = false
	current_enemy = null
	is_attacker = false

	if combat_dot and is_instance_valid(combat_dot):
		combat_dot.queue_free()
	combat_dot = null


func _update_engagement_forces(delta: float):
	if not engaged_with or not is_instance_valid(engaged_with):
		return

	var my_pos = global_position
	var enemy_pos = engaged_with.global_position
	var to_enemy = enemy_pos - my_pos
	var dist = to_enemy.length()
	if dist < 0.1: return

	var dir = to_enemy.normalized()
	var my_str = _get_strength()
	var enemy_str = engaged_with._get_strength()
	var relative = my_str / max(enemy_str, 1.0)

	var desired_dist := 13.5

	if dist < desired_dist:
		var penetration = desired_dist - dist
		var correction = dir * penetration * 1.2
		global_position -= correction * 0.6
		engaged_with.global_position += correction * 0.6

	var push_base = 6.5 * delta
	if is_attacker_in_engagement or relative > 0.78:
		var push = dir * push_base * clamp(relative, 0.5, 1.8)
		global_position += push * 0.45
		engaged_with.global_position -= push * 0.3
	else:
		global_position -= dir * push_base * 0.35

	global_position = global_position.normalized() * GLOBE_RADIUS
	engaged_with.global_position = engaged_with.global_position.normalized() * GLOBE_RADIUS

	_update_combat_dot()


func _update_combat_dot():
	if not combat_dot or not engaged_with or not is_instance_valid(combat_dot): return
	combat_dot.global_position = (global_position + engaged_with.global_position) * 0.5


func _create_combat_dot():
	if combat_dot and is_instance_valid(combat_dot):
		combat_dot.queue_free()

	combat_dot = MeshInstance3D.new()
	get_tree().current_scene.add_child(combat_dot)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := 0.8
	var v := [
		Vector3(-s,-s,-s), Vector3(s,-s,-s), Vector3(s,s,-s), Vector3(-s,s,-s),
		Vector3(-s,-s,s), Vector3(s,-s,s), Vector3(s,s,s), Vector3(-s,s,s)
	]
	var faces := [0,1,2, 2,3,0, 4,5,6, 6,7,4, 0,4,7, 7,3,0, 1,5,6, 6,2,1, 0,1,5, 5,4,0, 3,2,6, 6,7,3]
	for f in faces:
		st.add_vertex(v[f])
	combat_dot.mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.05, 0.05, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.1) * 8.0
	combat_dot.material_override = mat


func _resolve_unit_collisions(delta: float):
	if not collision_area: return
	var overlaps = collision_area.get_overlapping_areas()
	for oa in overlaps:
		var other = oa.get_parent()
		if not (other is GroundEntity) or other == self or not other.is_combat_unit: continue
		if not is_at_war_with(other.nation_code): continue
		var dist = global_position.distance_to(other.global_position)
		if not engaged_with and dist < 30.0:
			var i_am_attacker = _get_strength() > other._get_strength() * 0.8
			start_engagement(other, i_am_attacker)
			if other and not other.engaged_with:
				other.start_engagement(self, not i_am_attacker)


func is_at_war_with(other_nation: String) -> bool:
	var diplomacy = get_node_or_null("/root/DiplomacyManager")
	if diplomacy and diplomacy.has_method("is_at_war"):
		return diplomacy.is_at_war(nation_code, other_nation)
	return nation_code != other_nation and ((nation_code == "GER" and other_nation == "POL") or (nation_code == "POL" and other_nation == "GER"))


func take_combat_damage(soft_dmg: float, hard_dmg: float, org_dmg: float):
	current_manpower = max(0, current_manpower - int(soft_dmg + hard_dmg * 0.65))
	current_organization = max(0.0, current_organization - org_dmg)
	update_bars()
	if current_organization < 18.0:
		end_engagement()


func gain_experience(amount: float):
	experience = min(100.0, experience + amount)


func select():
	is_selected = true
	if wire_cube and wire_cube.material_override:
		wire_cube.material_override.emission = Color(0.6, 0.95, 1.0) * 9.0


func deselect():
	is_selected = false
	if wire_cube and wire_cube.material_override:
		wire_cube.material_override.emission = Color(0.35, 0.75, 1.0) * 5.5


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
	var v := [Vector3(-s,-s,-s), Vector3(s,-s,-s), Vector3(s,s,-s), Vector3(-s,s,-s),
			  Vector3(-s,-s,s), Vector3(s,-s,s), Vector3(s,s,s), Vector3(-s,s,s)]
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


func _apply_orientation():
	if global_position.length() > 10.0:
		var normal = global_position.normalized()
		look_at(global_position + normal * 50.0, Vector3.UP)


func _on_arrival():
	print("Einheit angekommen: ", entity_name)


func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(r * cos(lat_rad) * sin(lon_rad), r * sin(lat_rad), r * cos(lat_rad) * cos(lon_rad))


func _get_strength() -> float:
	return float(current_manpower) * clamp(current_organization / 100.0, 0.3, 1.4)


func _aggregate_from_battalions(bn_list: Array):
	# Originalen Code aus deiner alten Datei hier einfügen
	pass


func _load_battalion_templates() -> Dictionary:
	var path = "res://data/battalion_types.json"
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return json.data


func start_combat(enemy: GroundEntity, attacker_side: bool = false):
	start_engagement(enemy, attacker_side)


func end_combat():
	end_engagement()
