extends Node3D
class_name GroundEntity

@onready var sprite: Sprite3D = $Sprite3D
@onready var label: Label3D = $Label3D
@onready var click_area: Area3D = $ClickArea
@onready var collision_area_node: Area3D = $CollisionArea

var entity_id: String = ""
var entity_name: String = ""
var nation_code: String = ""
var entity_type: String = "division"
var current_lat: float = 0.0
var current_lon: float = 0.0
var is_selected: bool = false

var movement_speed: float = 0.65
var _target_lat: float = 0.0
var _target_lon: float = 0.0
var _has_target: bool = false

var raw_data: Dictionary = {}

const GLOBE_RADIUS := 1002.0

var equipment_readiness: float = 0.85
var manpower: int = 8000
var max_manpower: int = 8000
var organization: float = 80.0
var max_organization: float = 100.0
var soft_attack: float = 30.0
var hard_attack: float = 10.0
var defense: float = 50.0
var breakthrough: float = 20.0
var armor: float = 5.0
var piercing: float = 15.0
var supply_consumption: float = 3.5
var experience: float = 25.0
var is_combat_unit: bool = true
var type_display_name: String = "Division"
var required_equipment: Array = []

var supply: float = 75.0

const POSITION_ROTATION_DEGREES := 180.0

var status_bars: Array = []
var collision_area: Area3D = null

const MIN_SEPARATION_DISTANCE := 4.8
const COLLISION_RADIUS := 3.2


func _ready():
	if has_meta("unit_data"):
		var data = get_meta("unit_data")
		entity_id = data.get("id", name)
		entity_name = data.get("name", entity_id)
		entity_type = data.get("type", get_meta("unit_type", "division"))
		nation_code = get_meta("nation_code", "GER")

		if data.has("position") and data.position is Array and data.position.size() >= 3:
			var raw_pos = Vector3(data.position[0], data.position[1], data.position[2])
			var dir = raw_pos.normalized()
			
			if POSITION_ROTATION_DEGREES != 0.0:
				dir = dir.rotated(Vector3.UP, deg_to_rad(POSITION_ROTATION_DEGREES))
			
			global_position = dir * GLOBE_RADIUS

		raw_data = data

		manpower = data.get("manpower", manpower)
		max_manpower = data.get("max_manpower", max_manpower)
		organization = data.get("organization", organization)
		equipment_readiness = data.get("equipment_readiness", equipment_readiness)
		experience = data.get("experience", experience)
		required_equipment = data.get("required_equipment", [])
		
		if not data.has("supply"):
			supply = 75.0
		else:
			supply = data.get("supply", 75.0)

	if entity_name == "":
		entity_name = name

	if label:
		label.text = entity_name
		label.visible = true

	if sprite:
		sprite.visible = true
		
		match entity_type:
			"high_command":
				sprite.scale = Vector3(2.6, 2.6, 2.6)
				is_combat_unit = false
			"army_group":
				sprite.scale = Vector3(2.2, 2.2, 2.2)
				is_combat_unit = false
			"army":
				sprite.scale = Vector3(1.9, 1.9, 1.9)
				is_combat_unit = false
			"corps":
				sprite.scale = Vector3(1.55, 1.55, 1.55)
				is_combat_unit = false
			"brigade":
				sprite.scale = Vector3(1.15, 1.15, 1.15)
				is_combat_unit = true
			_:
				sprite.scale = Vector3(1.2, 1.2, 1.2)
				is_combat_unit = true

	type_display_name = entity_type.capitalize()

	call_deferred("_apply_orientation")

	print("GroundEntity ready: ", entity_name, " @ ", global_position)

	add_to_group("ground_entities")

	if is_combat_unit:
		call_deferred("_setup_status_on_unit")
		call_deferred("_setup_collision_area")


func _apply_orientation():
	if global_position.length() > 10.0:
		var normal = global_position.normalized()
		look_at(global_position + normal * 50.0, Vector3.UP)


func select():
	is_selected = true
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 3.0)
	if label:
		label.modulate = Color(1.0, 1.0, 0.3)


func deselect():
	is_selected = false
	if sprite:
		sprite.modulate = Color.WHITE
	if label:
		label.modulate = Color.WHITE


func move_to(new_lat: float, new_lon: float):
	_target_lat = new_lat
	_target_lon = new_lon
	_has_target = true


func _process(delta: float):
	if _has_target:
		var tm = get_node_or_null("/root/TimeManager")
		if tm and not tm.paused and tm.speed > 0:
			var sim_speed = float(tm.speed)
			var max_move_distance = (movement_speed * sim_speed * delta) / GLOBE_RADIUS * (180.0 / PI)

			var current_pos = global_position.normalized()
			var target_pos = _lat_lon_to_vector3(_target_lat, _target_lon, GLOBE_RADIUS).normalized()
			var angle_to_target = acos(clampf(current_pos.dot(target_pos), -1.0, 1.0))

			if angle_to_target <= max_move_distance or angle_to_target < 0.001:
				global_position = target_pos * GLOBE_RADIUS
				current_lat = _target_lat
				current_lon = _target_lon
				_has_target = false
				_on_arrival()
			else:
				var axis = current_pos.cross(target_pos).normalized()
				if axis.length() < 0.001:
					axis = Vector3.UP
				var partial_quat = Quaternion(axis, max_move_distance)
				var new_dir = partial_quat * current_pos
				global_position = new_dir * GLOBE_RADIUS

				var mag = global_position.length()
				current_lat = rad_to_deg(asin(global_position.y / mag))
				current_lon = rad_to_deg(atan2(global_position.x, global_position.z))

				var normal = global_position.normalized()
				look_at(global_position + normal * 50.0, Vector3.UP)

	_resolve_unit_collisions(delta)


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


func get_display_name() -> String:
	return entity_name

func is_division() -> bool:
	return entity_type == "division"


# ============================================
# Name + 3 Balken FEST auf der Einheit (ohne Billboard)
# Ganz easy, sauber, direkt am Icon
# ============================================
func _setup_status_on_unit():
	# Name direkt über der Einheit
	if label:
		label.position = Vector3(0, 2.4, 0.35)
		label.font_size = 20
		label.modulate = Color(1, 1, 1, 0.95)

	_create_status_bars()


func _create_status_bars():
	for bar in status_bars:
		if is_instance_valid(bar):
			bar.queue_free()
	status_bars.clear()

	var org_percent = clamp(organization, 0.0, 100.0)
	var man_percent = clamp(float(manpower) / float(max_manpower) * 100.0, 0.0, 100.0)
	var sup_percent = clamp(supply, 0.0, 100.0)

	var bar_max_width = 3.2
	var bar_height = 0.32
	var bar_spacing = 0.55
	var start_y = -1.55

	var bars_data = [
		{"label": "ORG", "percent": org_percent, "color": Color(0.3, 0.75, 1.0)},
		{"label": "MAN", "percent": man_percent, "color": Color(0.35, 0.9, 0.45)},
		{"label": "SUP", "percent": sup_percent, "color": Color(1.0, 0.7, 0.25)}
	]

	for i in range(bars_data.size()):
		var data = bars_data[i]
		var y_pos = start_y - (i * bar_spacing)

		# Balken-Hintergrund
		var bar_bg = MeshInstance3D.new()
		bar_bg.name = "BarBG_" + data.label
		var bar_bg_mesh = PlaneMesh.new()
		bar_bg_mesh.size = Vector2(bar_max_width, bar_height)
		bar_bg.mesh = bar_bg_mesh
		var bar_bg_mat = StandardMaterial3D.new()
		bar_bg_mat.albedo_color = Color(0.08, 0.08, 0.1, 0.9)
		bar_bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bar_bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bar_bg.material_override = bar_bg_mat
		add_child(bar_bg)
		bar_bg.position = Vector3(0, y_pos, 0.25)
		status_bars.append(bar_bg)

		# Farbiger Balken
		var bar = MeshInstance3D.new()
		bar.name = "Bar_" + data.label
		var bar_mesh = PlaneMesh.new()
		bar_mesh.size = Vector2(bar_max_width, bar_height)
		bar.mesh = bar_mesh
		var bar_mat = StandardMaterial3D.new()
		bar_mat.albedo_color = data.color
		bar_mat.emission_enabled = true
		bar_mat.emission = data.color * 0.55
		bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bar.material_override = bar_mat
		add_child(bar)
		
		var p = data.percent / 100.0
		bar.position = Vector3(-bar_max_width / 2.0 + (bar_max_width * p / 2.0), y_pos, 0.28)
		bar.scale = Vector3(p, 1.0, 1.0)
		status_bars.append(bar)

		# Kleines Label
		var bar_label = Label3D.new()
		bar_label.name = "BarLabel_" + data.label
		bar_label.text = data.label
		bar_label.font_size = 11
		bar_label.modulate = Color(0.9, 0.9, 0.92)
		bar_label.position = Vector3(-bar_max_width/2 - 0.65, y_pos, 0.3)
		add_child(bar_label)
		status_bars.append(bar_label)


func _setup_collision_area():
	if collision_area_node != null:
		collision_area = collision_area_node
	else:
		collision_area = Area3D.new()
		collision_area.name = "CollisionArea"
		add_child(collision_area)

	if collision_area.get_child_count() == 0 or not collision_area.get_child(0) is CollisionShape3D:
		var col_shape_node = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = COLLISION_RADIUS
		col_shape_node.shape = sphere
		collision_area.add_child(col_shape_node)

	collision_area.collision_layer = 1 << 1
	collision_area.collision_mask = 1 << 1
	collision_area.monitoring = true
	collision_area.monitorable = true


func _resolve_unit_collisions(delta: float):
	if collision_area == null or not is_combat_unit:
		return
	var overlaps = collision_area.get_overlapping_areas()
	for oa in overlaps:
		var parent = oa.get_parent()
		if parent == self or not (parent is GroundEntity):
			continue
		var other: GroundEntity = parent
		if not other.is_combat_unit:
			continue

		var to_self = global_position - other.global_position
		var dist = to_self.length()
		if dist < 0.001:
			global_position += Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)).normalized() * 0.3
			global_position = global_position.normalized() * GLOBE_RADIUS
			_apply_orientation()
			continue

		if dist >= MIN_SEPARATION_DISTANCE:
			continue

		var push_dir = to_self.normalized()
		var sep_needed = MIN_SEPARATION_DISTANCE - dist

		var my_str = _get_strength()
		var ot_str = other._get_strength()
		var inv_my = 1.0 / max(my_str, 1.0)
		var inv_ot = 1.0 / max(ot_str, 1.0)
		var total_inv = inv_my + inv_ot
		if total_inv <= 0.0:
			continue

		var disp = push_dir * sep_needed * 0.65
		var self_move = disp * (inv_my / total_inv)

		global_position += self_move
		global_position = global_position.normalized() * GLOBE_RADIUS
		_apply_orientation()


func _get_strength() -> float:
	return float(manpower) * clamp(organization / 100.0, 0.2, 1.5) + 10.0


func update_info_bars():
	pass
