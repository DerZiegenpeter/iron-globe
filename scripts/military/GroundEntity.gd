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

var _battalion_definitions: Dictionary = {}

# ====================== EQUIPMENT ======================
var equipment_readiness: float = 1.0
var required_equipment: Dictionary = {}
var missing_equipment: Dictionary = {}


func _ready():
	_load_battalion_definitions()


func _load_battalion_definitions():
	var path = "res://data/battalion_types.json"
	if not FileAccess.file_exists(path):
		print("Warning: battalion_types.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	_battalion_definitions = json.data
	print("Success: Battalion Types geladen:", _battalion_definitions.keys())


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
	_calculate_stats_from_composition()


func _apply_type_properties():
	type_display_name = entity_type.capitalize()
	is_combat_unit = entity_type in ["division", "brigade"]


func _calculate_stats_from_composition():
	if not is_combat_unit:
		return

	var composition = raw_data.get("composition", [])
	if composition.is_empty():
		manpower = raw_data.get("manpower", 8000)
		max_manpower = raw_data.get("max_manpower", manpower)
		organization = raw_data.get("organization", 80.0)
		max_organization = raw_data.get("max_organization", 100.0)
		soft_attack = raw_data.get("soft_attack", 30.0)
		hard_attack = raw_data.get("hard_attack", 10.0)
		defense = raw_data.get("defense", 50.0)
		breakthrough = raw_data.get("breakthrough", 20.0)
		supply_consumption = raw_data.get("supply_consumption", 3.5)
		return

	manpower = 0
	max_manpower = 0
	soft_attack = 0.0
	hard_attack = 0.0
	defense = 0.0
	breakthrough = 0.0
	supply_consumption = 0.0

	for entry in composition:
		var bat_type = entry.get("type", "")
		var amount = entry.get("amount", 1)
		var bat_data = _battalion_definitions.get(bat_type, {})

		if bat_data.is_empty():
			print("Warning: Unbekannter Battalion-Typ:", bat_type)
			continue

		manpower += int(bat_data.get("manpower", 0)) * amount
		max_manpower += int(bat_data.get("manpower", 0)) * amount
		soft_attack += float(bat_data.get("soft_attack", 0)) * amount
		hard_attack += float(bat_data.get("hard_attack", 0)) * amount
		defense += float(bat_data.get("defense", 0)) * amount
		breakthrough += float(bat_data.get("breakthrough", 0)) * amount
		supply_consumption += float(bat_data.get("supply_consumption", 0)) * amount

	organization = 75.0
	max_organization = 100.0
	experience = raw_data.get("experience", 30.0)

	# Equipment Readiness berechnen
	calculate_equipment_readiness()


# ====================== EQUIPMENT SYSTEM ======================

func calculate_equipment_readiness():
	var equip_manager = get_node_or_null("/root/EquipmentManager")
	if not equip_manager or not is_combat_unit:
		equipment_readiness = 1.0
		return

	required_equipment = equip_manager.get_required_equipment(raw_data.get("composition", []))

	if required_equipment.is_empty():
		equipment_readiness = 1.0
		return

	var nation = nation_code
	var stock = equip_manager.get_stockpile(nation)

	var total_shortage := 0.0
	var total_required := 0

	for equip_id in required_equipment:
		var needed = required_equipment[equip_id]
		var available = stock.get(equip_id, 0)
		total_required += needed

		if available < needed:
			total_shortage += (needed - available)

	if total_required <= 0:
		equipment_readiness = 1.0
	else:
		equipment_readiness = clamp(1.0 - (total_shortage / total_required), 0.0, 1.0)

	# Fehlende Ausrüstung speichern
	missing_equipment.clear()
	for equip_id in required_equipment:
		var needed = required_equipment[equip_id]
		var available = stock.get(equip_id, 0)
		if available < needed:
			missing_equipment[equip_id] = needed - available


func get_readiness_multiplier() -> float:
	return equipment_readiness


# ====================== REST ======================

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
