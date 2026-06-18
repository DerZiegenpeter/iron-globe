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

# === Fixe Bewegungsgeschwindigkeit (Einheiten pro Tag) ===
var movement_speed: float = 120.0

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
	print("Ausgewählt:", entity_name)

func deselect():
	is_selected = false
	if sprite:
		sprite.modulate = Color.WHITE

func move_to(new_lat: float, new_lon: float):
	current_lat = new_lat
	current_lon = new_lon

	var target_pos = _lat_lon_to_vector3(new_lat, new_lon, 1002.0)
	var distance = position.distance_to(target_pos)

	# Dauer basierend auf fixer Geschwindigkeit berechnen
	var duration = distance / movement_speed
	if duration < 0.8:
		duration = 0.8

	print(">>> %s bewegt sich (Distanz: %.1f | Dauer: %.1f Tage)" % [entity_name, distance, duration])

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target_pos, duration)
	tween.finished.connect(_ready_after_add)

func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
