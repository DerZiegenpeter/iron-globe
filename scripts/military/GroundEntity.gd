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

# ====================== NEU: FRONTLINE ======================
var assigned_frontline_id: int = 0

# ====================== BEWEGUNG ======================
var movement_speed: float = 0.12
var current_lat: float = 0.0
var current_lon: float = 0.0
var _target_lat: float = 0.0
var _target_lon: float = 0.0
var _has_target: bool = false

var _move_start_dir: Vector3 = Vector3.ZERO
var _move_target_dir: Vector3 = Vector3.ZERO
var _move_total_angle: float = 0.0
var _move_progress: float = 0.0

# ====================== ENGAGEMENT ======================
var engaged_with: GroundEntity = null
var is_attacker_in_engagement: bool = false
var combat_dot: MeshInstance3D = null
var combat_anchor: Vector3 = Vector3.ZERO
var retreat_accumulator: float = 0.0
var anchored_distance: float = 0.0

const MAX_RETREAT_TIME := 4.5
const ENGAGEMENT_BREAK_DIST := 42.0

var in_combat: bool = false
var current_enemy: GroundEntity = null
var is_attacker: bool = false
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


func move_to(new_lat: float, new_lon: float):
	_target_lat = new_lat
	_target_lon = new_lon
	_has_target = true

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
				global_position = _move_target_dir * GLOBE_RADIUS
				current_lat = _target_lat
				current_lon = _target_lon
				_has_target = false
				_on_arrival()
				_apply_orientation()
				return

			_move_progress += (angular_speed * delta) / _move_total_angle
			_move_progress = clamp(_move_progress, 0.0, 1.0)

			var new_dir = _move_start_dir.slerp(_move_target_dir, _move_progress)
			global_position = new_dir * GLOBE_RADIUS

			var mag = global_position.length()
			current_lat = rad_to_deg(asin(global_position.y / mag))
			current_lon = rad_to_deg(atan2(global_position.x, global_position.z))

			_apply_orientation()

			if _move_progress >= 1.0:
				global_position = _move_target_dir * GLOBE_RADIUS
				current_lat = _target_lat
				current_lon = _target_lon
				_has_target = false
				_on_arrival()
				_apply_orientation()

	var tm = get_node_or_null("/root/TimeManager")
	var time_running = tm and not tm.paused and tm.speed > 0

	if engaged_with and is_instance_valid(engaged_with) and time_running:
		_update_engagement_forces(delta)
		_check_disengage_conditions(delta)


# ====================== VISUELLE FUNKTIONEN (ORIGINAL AUS GITHUB) ======================
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


func update_bars():
	if not org_bar or not man_bar or not sup_bar:
		return
	_set_vertical_bar(org_bar, clamp(current_organization / 100.0, 0.0, 1.0), Color(0.3, 0.75, 1.0))
	_set_vertical_bar(man_bar, clamp(float(current_manpower) / float(max_manpower), 0.0, 1.0), Color(0.35, 0.9, 0.45))
	_set_vertical_bar(sup_bar, clamp(equipment_fulfillment, 0.0, 1.0), Color(0.95, 0.75, 0.2))


func _set_vertical_bar(bar: MeshInstance3D, value: float, color: Color):
	if not bar:
		return
	bar.scale.y = max(value, 0.05)
	if bar.material_override:
		bar.material_override.albedo_color = color
		bar.material_override.emission = color * 6.0


func _apply_orientation():
	if global_position.length() > 10.0:
		var normal = global_position.normalized()
		look_at(global_position + normal * 50.0, Vector3.UP)


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


func _aggregate_from_battalions(battalion_data: Array):
	pass


func _update_engagement_forces(delta: float):
	pass


func _check_disengage_conditions(delta: float):
	pass


func _on_arrival():
	pass


func select():
	is_selected = true


func deselect():
	is_selected = false


func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
