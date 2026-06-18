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

# Bewegung in Einheiten pro simulierter Stunde
@export var movement_speed: float = 0.65   # ca. 4 km/h → realistisch für motorisierte Division

var _target_lat: float = 0.0
var _target_lon: float = 0.0
var _has_target: bool = false


func setup(data: Dictionary, type: String = "division"):
	entity_id = data.get("id", "")
	entity_name = data.get("name", "Formation")
	entity_type = type

	var pos = data.get("position", {})
	current_lat = float(pos.get("lat", 0.0))
	current_lon = float(pos.get("lon", 0.0))

	position = _lat_lon_to_vector3(current_lat, current_lon, 1002.0)

	if label:
		label.text = entity_name


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

	# Wie weit wir in diesem Frame maximal kommen (in Grad)
	var max_move_distance := (movement_speed * sim_speed * delta) / 1002.0 * (180.0 / PI)

	var current_pos := position.normalized()
	var target_pos := _lat_lon_to_vector3(_target_lat, _target_lon, 1002.0).normalized()

	var angle_to_target := acos(clampf(current_pos.dot(target_pos), -1.0, 1.0))

	if angle_to_target <= max_move_distance or angle_to_target < 0.001:
		# Ziel erreicht
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

		# Lat/Lon aktualisieren
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
