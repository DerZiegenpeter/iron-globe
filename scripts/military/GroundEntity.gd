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

# ====================== BEWEGUNG (KONSTANTE GESCHWINDIGKEIT) ======================
var movement_speed: float = 0.12  # Grad pro Sekunde (bei sim_speed=1)
var current_lat: float = 0.0
var current_lon: float = 0.0
var _target_lat: float = 0.0
var _target_lon: float = 0.0
var _has_target: bool = false

# ====================== ENGAGEMENT / KAMPF (mit ANKER + KLEBER) ======================
var engaged_with: GroundEntity = null
var is_attacker_in_engagement: bool = false
var combat_dot: MeshInstance3D = null
var combat_anchor: Vector3 = Vector3.ZERO
var retreat_accumulator: float = 0.0
var anchored_distance: float = 0.0   # Distanz beim ersten Berühren (wird beibehalten)

const MAX_RETREAT_TIME := 4.5
const ENGAGEMENT_BREAK_DIST := 42.0

var in_combat: bool = false
var current_enemy: GroundEntity = null
var is_attacker: bool = false

# Für CombatManager Kompatibilität (falls Rote Linie erwartet wird)
var combat_line: MeshInstance3D = null

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


# ====================== GANZ ANDERE VARIANTE: Progress-basiertes Great-Circle Movement ======================
# Kein inkrementelles Drehen mehr → sauberes, exaktes Ankommen ohne Zucken

var _move_start_dir: Vector3 = Vector3.ZERO
var _move_target_dir: Vector3 = Vector3.ZERO
var _move_total_angle: float = 0.0
var _move_progress: float = 0.0

func move_to(new_lat: float, new_lon: float):
	_target_lat = new_lat
	_target_lon = new_lon
	_has_target = true

	# Progress-System zurücksetzen
	_move_start_dir = global_position.normalized()
	_move_target_dir = _lat_lon_to_vector3(new_lat, new_lon, GLOBE_RADIUS).normalized()
	_move_total_angle = acos(clampf(_move_start_dir.dot(_move_target_dir), -1.0, 1.0))
	_move_progress = 0.0


func _process(delta: float):
	if _has_target:
		var tm = get_node_or_null("/root/TimeManager")
		if tm and not tm.paused and tm.speed > 0:
			var sim_speed = float(tm.speed)
			var angular_speed = deg_to_rad(movement_speed * sim_speed)

			if _move_total_angle < 0.001:
				# Extrem kurze Strecke → direkt hin
				global_position = _move_target_dir * GLOBE_RADIUS
				current_lat = _target_lat
				current_lon = _target_lon
				_has_target = false
				_on_arrival()
				_apply_orientation()
				return

			# Fortschritt erhöhen
			_move_progress += (angular_speed * delta) / _move_total_angle
			_move_progress = clamp(_move_progress, 0.0, 1.0)

			# Exakte Position auf dem Großkreis
			var new_dir = _move_start_dir.slerp(_move_target_dir, _move_progress)
			global_position = new_dir * GLOBE_RADIUS

			var mag = global_position.length()
			current_lat = rad_to_deg(asin(global_position.y / mag))
			current_lon = rad_to_deg(atan2(global_position.x, global_position.z))

			_apply_orientation()

			# Sauberes Ende
			if _move_progress >= 1.0:
				global_position = _move_target_dir * GLOBE_RADIUS
				current_lat = _target_lat
				current_lon = _target_lon
				_has_target = false
				_on_arrival()
				_apply_orientation()

	# === ENGAGEMENT / KAMPF (nur wenn Zeit läuft) ===
	var tm = get_node_or_null("/root/TimeManager")
	var time_running = tm and not tm.paused and tm.speed > 0

	if engaged_with and is_instance_valid(engaged_with) and time_running:
		_update_engagement_forces(delta)
		_check_disengage_conditions(delta)
	else:
		if combat_anchor.length_squared() > 1.0 or retreat_accumulator > 0.0 or anchored_distance > 0.1:
			combat_anchor = Vector3.ZERO
			retreat_accumulator = 0.0
			anchored_distance = 0.0
		_resolve_unit_collisions(delta)


# ====================== ENGAGEMENT SYSTEM - NEU: Runder Anker-Punkt + Kleber ======================

func start_engagement(enemy: GroundEntity, am_i_attacker: bool = false):
	if engaged_with == enemy or enemy == self or not is_instance_valid(enemy):
		return
	end_engagement()

	engaged_with = enemy
	is_attacker_in_engagement = am_i_attacker
	in_combat = true
	current_enemy = enemy
	is_attacker = am_i_attacker

	# Runden Anker-Punkt (roter leuchtender Punkt) erzeugen / teilen
	if not combat_dot or not is_instance_valid(combat_dot):
		_create_combat_dot()
	if engaged_with and (not engaged_with.combat_dot or not is_instance_valid(engaged_with.combat_dot)):
		engaged_with.combat_dot = combat_dot

	# Anker-Position wo sie sich treffen (initialer Treffpunkt) - leicht über der Oberfläche
	if combat_anchor.length_squared() < 10.0:
		combat_anchor = _get_mid_anchor()
	if engaged_with and engaged_with.combat_anchor.length_squared() < 10.0:
		engaged_with.combat_anchor = combat_anchor

	# Distanz beim ersten Kontakt merken (wird während des Engagements beibehalten)
	if anchored_distance < 0.1:
		anchored_distance = clamp(global_position.distance_to(engaged_with.global_position), 6.0, 38.0)
	if engaged_with and engaged_with.anchored_distance < 0.1:
		engaged_with.anchored_distance = anchored_distance

	# === EXAKTES EINFRIEREN der Kontakt-Distanz (kein Rutschen beim ersten Treffen) ===
	var cur_dist = global_position.distance_to(engaged_with.global_position)
	if cur_dist > 0.5:
		var mid = (global_position + engaged_with.global_position) * 0.5
		var ddir = (engaged_with.global_position - global_position).normalized()
		var half = cur_dist * 0.5
		global_position = (mid - ddir * half).normalized() * GLOBE_RADIUS
		engaged_with.global_position = (mid + ddir * half).normalized() * GLOBE_RADIUS

	_update_combat_dot()


func end_engagement():
	var other = engaged_with
	engaged_with = null
	is_attacker_in_engagement = false
	in_combat = false
	current_enemy = null
	is_attacker = false
	combat_anchor = Vector3.ZERO
	retreat_accumulator = 0.0
	anchored_distance = 0.0

	if combat_dot and is_instance_valid(combat_dot):
		combat_dot.queue_free()
	combat_dot = null

	if other and is_instance_valid(other) and other.engaged_with == self:
		other.end_engagement()


func _get_mid_anchor() -> Vector3:
	if not engaged_with or not is_instance_valid(engaged_with):
		return global_position
	var mid_dir = (global_position.normalized() + engaged_with.global_position.normalized()).normalized()
	return mid_dir * (GLOBE_RADIUS + 1.8)  # etwas über der Kugeloberfläche für Sichtbarkeit


func _update_engagement_forces(delta: float):
	if not engaged_with or not is_instance_valid(engaged_with):
		return

	var my_pos = global_position
	var en_pos = engaged_with.global_position
	var to_en = en_pos - my_pos
	var dist = to_en.length()
	if dist < 0.8:
		return

	var dir = to_en.normalized()
	var my_str = _get_strength()
	var en_str = engaged_with._get_strength()
	var rel = my_str / max(en_str, 1.0)

	# === 1. HARTE MINIMUM-DISTANZ (nur bei echtem Clip verhindern) ===
	var min_dist: float = max(anchored_distance * 0.5, 8.0)
	if dist < min_dist:
		var push_away = (min_dist - dist) * 8.0 * delta
		global_position -= dir * push_away * 0.5
		engaged_with.global_position += dir * push_away * 0.5

	# === 2. KLEBER zum Anker + Stärke-Push (Distanz wird nicht aktiv korrigiert) ===
	# Die Distanz beim ersten Berühren bleibt weitestgehend erhalten (kein aktives Hin- und Her-Rutschen)
	if combat_anchor.length_squared() > 10.0:
		var to_anchor_my = combat_anchor - my_pos
		var anchor_d = to_anchor_my.length()
		if anchor_d > 16.0:
			var glue = clamp((anchor_d - 16.0) / 14.0, 0.0, 1.8) * 8.0 * delta
			global_position += to_anchor_my.normalized() * glue * 0.55

	# === 4. Angreifer-Vorteil / Kampf-Dynamik (etwas abgeschwächt) ===
	var push_base = 4.8 * delta
	if is_attacker_in_engagement or rel > 0.82:
		var push = dir * push_base * clamp(rel, 0.5, 1.6)
		global_position += push * 0.42
		engaged_with.global_position -= push * 0.30
	else:
		global_position -= dir * push_base * 0.22

	# Auf Kugeloberfläche projizieren
	global_position = global_position.normalized() * GLOBE_RADIUS
	engaged_with.global_position = engaged_with.global_position.normalized() * GLOBE_RADIUS

	_update_combat_dot()


func _check_disengage_conditions(delta: float):
	if not engaged_with or not is_instance_valid(engaged_with):
		return

	# Distanz zu groß → beide haben sich wegbewegt
	var dist = global_position.distance_to(engaged_with.global_position)
	if dist > ENGAGEMENT_BREAK_DIST:
		end_engagement()
		return

	# Rückwärts-Lauf Timer (eine Einheit läuft lang genug rückwärts)
	if _has_target:
		var target_pos = _lat_lon_to_vector3(_target_lat, _target_lon, GLOBE_RADIUS)
		var to_target = (target_pos - global_position).normalized()
		var to_enemy = (engaged_with.global_position - global_position).normalized()
		var alignment = to_target.dot(to_enemy)  # positiv = vorwärts/zum Feind, negativ = rückwärts

		var tm = get_node_or_null("/root/TimeManager")
		var sim_dt = delta * (float(tm.speed) if tm and tm.speed > 0 else 1.0)

		if alignment < -0.28:  # klar rückwärts
			retreat_accumulator += sim_dt
			if retreat_accumulator > MAX_RETREAT_TIME:
				print(entity_name + " zieht sich zurück → Engagement beendet")
				end_engagement()
				return
		else:
			retreat_accumulator = max(0.0, retreat_accumulator - sim_dt * 1.8)


func _update_combat_dot():
	if not combat_dot or not is_instance_valid(combat_dot) or not engaged_with or not is_instance_valid(engaged_with):
		return
	# Mittelpunkt leicht über der Oberfläche (runder Punkt)
	var mid_dir = (global_position.normalized() + engaged_with.global_position.normalized()).normalized()
	combat_dot.global_position = mid_dir * (GLOBE_RADIUS + 2.2)


func _create_combat_dot():
	if combat_dot and is_instance_valid(combat_dot):
		combat_dot.queue_free()

	combat_dot = MeshInstance3D.new()
	get_tree().current_scene.add_child(combat_dot)

	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.3
	combat_dot.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.08, 0.08, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.1) * 5.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	combat_dot.material_override = mat
	combat_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _resolve_unit_collisions(delta: float):
	if not collision_area:
		return
	var overlaps = collision_area.get_overlapping_areas()
	for oa in overlaps:
		var other = oa.get_parent()
		if not (other is GroundEntity) or other == self or not other.is_combat_unit:
			continue
		if not is_at_war_with(other.nation_code):
			continue
		var dist = global_position.distance_to(other.global_position)
		if not engaged_with and dist < 28.0:
			var i_am_attacker = _get_strength() > other._get_strength() * 0.82
			start_engagement(other, i_am_attacker)
			if other and not other.engaged_with and is_instance_valid(other):
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
	if not org_bar or not man_bar or not sup_bar:
		return
	_set_vertical_bar(org_bar, clamp(current_organization / 100.0, 0.0, 1.0), Color(0.3, 0.75, 1.0))
	_set_vertical_bar(man_bar, clamp(float(current_manpower) / float(max_manpower), 0.0, 1.0), Color(0.35, 0.9, 0.45))
	_set_vertical_bar(sup_bar, clamp(equipment_fulfillment, 0.0, 1.0), Color(0.95, 0.75, 0.2))


func _set_vertical_bar(bar: MeshInstance3D, percent: float, color: Color):
	if not bar or not bar.material_override:
		return
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
		if not bar:
			continue
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
	if not wire_cube:
		return
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
	# TODO: Originalen Aggregations-Code aus alter Version hier einfügen (soft_attack, etc. aus Battalions berechnen)
	pass


func _load_battalion_templates() -> Dictionary:
	var path = "res://data/battalion_types.json"
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return json.data


func start_combat(enemy: GroundEntity, attacker_side: bool = false):
	start_engagement(enemy, attacker_side)


func end_combat():
	end_engagement()
