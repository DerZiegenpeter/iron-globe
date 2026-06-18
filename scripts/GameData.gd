extends Node3D

@export var entity_id: String = ""
@export var entity_name: String = ""
@export var nation_code: String = ""
@export var entity_type: String = "division"

@onready var sprite: Sprite3D = $Sprite3D
@onready var label: Label3D = $Label3D

var current_lat: float = 0.0
var current_lon: float = 0.0
var is_selected: bool = false

var movement_speed: float = 80.0

var _move_tween: Tween = null
var _target_lat: float = 0.0
var _target_lon: float = 0.0


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
	var radius := 1002.0
	var target_pos := _lat_lon_to_vector3(new_lat, new_lon, radius)

	var start_dir := position.normalized()
	var end_dir := target_pos.normalized()

	var dot := clampf(start_dir.dot(end_dir), -1.0, 1.0)
	var angle := acos(dot)
	var arc_length := radius * angle

	var tm := get_node_or_null("/root/TimeManager")
	var sim_speed := 1.0
	if tm and not tm.paused and tm.speed > 0:
		sim_speed = float(tm.speed)

	var duration := (arc_length / movement_speed) / sim_speed
	duration = clampf(duration, 0.6, 12.0)

	_target_lat = new_lat
	_target_lon = new_lon

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)

	# Stabile Variante mit Callable + bind (empfohlen)
	_move_tween.tween_method(
		Callable(self, "_apply_sphere_move").bind(start_dir, end_dir),
		0.0, 1.0, duration
	)

	_move_tween.finished.connect(_on_movement_finished)


func _apply_sphere_move(start_dir: Vector3, end_dir: Vector3, progress: float):
	_update_position_on_sphere(start_dir, end_dir, progress)


func _update_position_on_sphere(start_dir: Vector3, end_dir: Vector3, progress: float):
	if start_dir.is_equal_approx(end_dir):
		position = start_dir * 1002.0
		return

	var angle := acos(clampf(start_dir.dot(end_dir), -1.0, 1.0))
	if angle < 0.0001:
		position = start_dir * 1002.0
		return

	var axis := start_dir.cross(end_dir).normalized()
	var partial_quat := Quaternion(axis, angle * progress)
	var current_dir := partial_quat * start_dir
	position = current_dir * 1002.0


func _on_movement_finished():
	current_lat = _target_lat
	current_lon = _target_lon

	var normal := position.normalized()
	look_at(position + normal * 100.0, Vector3.UP)


func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
