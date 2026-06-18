extends Node3D
class_name GroundEntity

@export var entity_id: String = ""
@export var entity_name: String = ""
@export var nation_code: String = ""
@export var entity_type: String = "division"

@onready var sprite: Sprite3D = $Sprite3D
@onready var label: Label3D = $Label3D

var current_lat: float = 0.0
var current_lon: float = 0.0
var is_selected: bool = false

@export var movement_speed: float = 0.65

var _target_lat: float = 0.0
var _target_lon: float = 0.0
var _has_target: bool = false

# ====================== STATISTIKEN ======================
var is_combat_unit: bool = false
var type_display_name: String = ""

var manpower: int = 0
var max_manpower: int = 0
var organization: float = 0.0
var max_organization: float = 0.0
var soft_attack: float = 0.0
var hard_attack: float = 0.0
var defense: float = 0.0
var breakthrough: float = 0.0
var armor: float = 0.0
var piercing: float = 0.0
var supply_consumption: float = 0.0
var experience: float = 0.0

var entity_subtype: String = ""
var template_name: String = ""
var raw_data: Dictionary = {}

# Typ-Definitionen aus JSON
var _type_definitions: Dictionary = {}


func _ready():
	_load_type_definitions()


func _load_type_definitions():
	var path = "res://data/ground_entity_types.json"
	if not FileAccess.file_exists(path):
		print("⚠️ ground_entity_types.json nicht gefunden! Fallback wird verwendet.")
		_create_fallback_definitions()
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	_type_definitions = json.data.get("types", {})
	print("✅ Ground Entity Typen geladen:", _type_definitions.keys())


func _create_fallback_definitions():
	# Fallback falls JSON fehlt
	_type_definitions = {
		"division": {"is_combat_unit": true, "display_name": "Division"},
		"brigade": {"is_combat_unit": true, "display_name": "Brigade"},
		"corps": {"is_combat_unit": false, "display_name": "Korps"},
		"army": {"is_combat_unit": false, "display_name": "Armee"},
		"army_group": {"is_combat_unit": false, "display_name": "Heeresgruppe"},
		"high_command": {"is_combat_unit": false, "display_name": "Oberkommando"}
	}


func setup(data: Dictionary, type: String = "division"):
	entity_id = data.get("id", "")
	entity_name = data.get("name", "Formation")
	entity_type = type
	entity_subtype = data.get("type", "")
	template_name = data.get("template", "")
	nation_code = data.get("nation_code", "GER").to_upper()

	var pos = data.get("position", {})
	current_lat = float(pos.get("lat", 0.0))
	current_lon = float(pos.get("lon", 0.0))

	position = _lat_lon_to_vector3(current_lat, current_lon, 1002.0)

	if label:
		label.text = entity_name

	raw_data = data.duplicate()

	_apply_type_properties()
	_load_combat_stats(data)


func _apply_type_properties():
	var type_data = _type_definitions.get(entity_type, {})
	type_display_name = type_data.get("display_name", entity_type.capitalize())
	is_combat_unit = type_data.get("is_combat_unit", false)


func _load_combat_stats(data: Dictionary):
	if is_combat_unit:
		manpower = data.get("manpower", 8000)
		max_manpower = data.get("max_manpower", manpower)
		organization = data.get("organization", 80.0)
		max_organization = data.get("max_organization", 100.0)
		soft_attack = data.get("soft_attack", 30.0)
		hard_attack = data.get("hard_attack", 10.0)
		defense = data.get("defense", 50.0)
		breakthrough = data.get("breakthrough", 20.0)
		armor = data.get("armor", 5.0)
		piercing = data.get("piercing", 15.0)
		supply_consumption = data.get("supply_consumption", 3.5)
		experience = data.get("experience", 25.0)
	else:
		# Organisations-Einheiten bekommen keine Kampfwerte
		pass


func _ready_after_add():
	add_to_group("ground_entities")
	var normal = position.normalized()
	look_at(position + normal * 100.0, Vector3.UP)


func select():
	is_selected = true
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 3.0)


func deselect():
	is_selected = false
	if sprite:
		sprite.modulate = Color.WHITE


func move_to(new_lat: float, new_lon: float):
	_target_lat = new_lat
	_target_lon = new_lon
	_has_target = true


func _process(delta: float):
	if not _has_target:
		return

	var tm := get_node_or_null("/root/TimeManager")
	if not tm or tm.paused or tm.speed <= 0:
		return

	var sim_speed := float(tm.speed)
	var max_move_distance := (movement_speed * sim_speed * delta) / 1002.0 * (180.0 / PI)

	var current_pos := position.normalized()
	var target_pos := _lat_lon_to_vector3(_target_lat, _target_lon, 1002.0).normalized()
	var angle_to_target := acos(clampf(current_pos.dot(target_pos), -1.0, 1.0))

	if angle_to_target <= max_move_distance or angle_to_target < 0.001:
		position = target_pos * 1002.0
		current_lat = _target_lat
		current_lon = _target_lon
		_has_target = false
		_on_arrival()
	else:
		var axis := current_pos.cross(target_pos).normalized()
		var partial_quat := Quaternion(axis, max_move_distance)
		var new_dir := partial_quat * current_pos
		position = new_dir * 1002.0

		var mag = position.length()
		current_lat = rad_to_deg(asin(position.y / mag))
		current_lon = rad_to_deg(atan2(position.x, position.z))


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


# ====================== HELPER ======================

func get_display_name() -> String:
	return entity_name

func is_division() -> bool:
	return entity_type == "division"

func is_organizational_unit() -> bool:
	return not is_combat_unit
