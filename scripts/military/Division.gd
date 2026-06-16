extends Node3D
class_name Division

@export var unit_id: String = ""
@export var unit_name: String = "Division"
@export var nation_code: String = ""
@export var division_type: String = "infantry"

@onready var sprite: Sprite3D = $Sprite3D
@onready var label: Label3D = $Label3D

var current_lat: float = 0.0
var current_lon: float = 0.0

func _ready():
	if label:
		label.text = unit_name

# Wird vom MilitaryManager aufgerufen
func setup(data: Dictionary):
	unit_id = data.get("id", "")
	unit_name = data.get("name", "Division")
	nation_code = data.get("nation", nation_code)
	division_type = data.get("type", "infantry")
	
	var pos = data.get("position", {})
	current_lat = float(pos.get("lat", 0.0))
	current_lon = float(pos.get("lon", 0.0))
	
	update_world_position()
	
	if label:
		label.text = unit_name

func update_world_position():
	var world_pos = _lat_lon_to_vector3(current_lat, current_lon, 1002.0)
	position = world_pos
	
	# Ausrichtung zur Kugeloberfläche
	look_at(Vector3.ZERO, Vector3.UP)
	rotate_object_local(Vector3.RIGHT, PI/2)

func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)

# Für spätere Bewegung
func move_to(new_lat: float, new_lon: float, duration: float = 3.0):
	current_lat = new_lat
	current_lon = new_lon
	var target_pos = _lat_lon_to_vector3(new_lat, new_lon, 1002.0)
	
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)\
		 .set_trans(Tween.TRANS_SINE)\
		 .set_ease(Tween.EASE_IN_OUT)
	
	tween.finished.connect(update_world_position)
