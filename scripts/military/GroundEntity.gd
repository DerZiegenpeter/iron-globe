extends Node3D
class_name GroundEntity

@onready var sprite: Sprite3D = $Sprite3D
@onready var label: Label3D = $Label3D
@onready var click_area: Area3D = $ClickArea

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

# === HIER DEN WERT ÄNDERN, bis die Einheiten in Europa erscheinen ===
const POSITION_ROTATION_DEGREES := 180.0

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

	if entity_name == "":
		entity_name = name

	if label:
		label.text = entity_name
		label.visible = true

	if sprite:
		sprite.visible = true
		if entity_type in ["high_command", "army_group", "army", "corps"]:
			sprite.scale = Vector3(1.8, 1.8, 1.8)
			is_combat_unit = false
		else:
			sprite.scale = Vector3(1.2, 1.2, 1.2)
			is_combat_unit = true

	type_display_name = entity_type.capitalize()

	call_deferred("_apply_orientation")

	print("GroundEntity ready: ", entity_name, " @ ", global_position)

	add_to_group("ground_entities")


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
	if not _has_target:
		return

	var tm = get_node_or_null("/root/TimeManager")
	if not tm or tm.paused or tm.speed <= 0:
		return

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
