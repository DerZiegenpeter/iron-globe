extends Node3D
class_name GroundEntity

# GroundEntity - Militärische Einheit auf dem Globus (Division, Brigade, HQ etc.)
# Wird von MilitaryManager gespawnt. Unterstützt Orientierung zur Oberfläche (keine "Türme" mehr)
# und sanfte Bewegung mit TimeManager-Geschwindigkeit.

@onready var sprite: Sprite3D = $Sprite3D
@onready var label: Label3D = $Label3D
@onready var click_area: Area3D = $ClickArea

# Interne Daten
var entity_id: String = ""
var entity_name: String = ""
var nation_code: String = ""
var entity_type: String = "division"
var current_lat: float = 0.0
var current_lon: float = 0.0
var is_selected: bool = false

# Bewegung
var movement_speed: float = 0.65
var _target_lat: float = 0.0
var _target_lon: float = 0.0
var _has_target: bool = false

# Stats (werden bei Bedarf aus Meta oder Fallback geladen)
var is_combat_unit: bool = false
var manpower: int = 0
var max_manpower: int = 0
var organization: float = 80.0
var max_organization: float = 100.0

func _ready():
	# === Metadaten vom MilitaryManager auslesen (aktueller Spawn-Stil) ===
	if has_meta("unit_data"):
		var data = get_meta("unit_data")
		entity_id = data.get("id", name)
		entity_name = data.get("name", entity_id)
		entity_type = data.get("type", get_meta("unit_type", "division"))
		nation_code = get_meta("nation_code", "GER")
		
		# Position aus Array oder Meta übernehmen
		if data.has("position") and data.position is Array and data.position.size() >= 3:
			global_position = Vector3(data.position[0], data.position[1], data.position[2])
		elif has_meta("position"):  # falls mal anders
			pass

		raw_data = data  # für spätere Nutzung

	# Fallback falls keine Meta
	if entity_name == "":
		entity_name = name

	# Label setzen
	if label:
		label.text = entity_name
		label.visible = true

	# Sprite anpassen
	if sprite:
		sprite.visible = true
		if entity_type in ["high_command", "army_group", "army", "corps"]:
			sprite.scale = Vector3(1.8, 1.8, 1.8)
		else:
			sprite.scale = Vector3(1.2, 1.2, 1.2)

	# === WICHTIG: Radiale Orientierung → keine "Türme" mehr, schön auf dem Boden ===
	# Dreht den Node3D so, dass er "nach außen" schaut (normal der Kugeloberfläche)
	if global_position.length() > 10.0:  # nur wenn sinnvoll positioniert
		var normal = global_position.normalized()
		look_at(global_position + normal * 50.0, Vector3.UP)

	print("GroundEntity ready: ", entity_name, " (", entity_type, ") @ ", global_position)

	# Optional: Gruppe für spätere Abfragen
	add_to_group("ground_entities")


var raw_data: Dictionary = {}  # für Kompatibilität

func select():
	is_selected = true
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 3.0)  # hell leuchten
	if label:
		label.modulate = Color(1.0, 1.0, 0.3)
	print("SELECTED: ", entity_name)


func deselect():
	is_selected = false
	if sprite:
		sprite.modulate = Color.WHITE
	if label:
		label.modulate = Color.WHITE
	print("DESELECTED: ", entity_name)


func move_to(new_lat: float, new_lon: float):
	_target_lat = new_lat
	_target_lon = new_lon
	_has_target = true
	print(entity_name, " bekommt Bewegungsziel: lat=", new_lat, " lon=", new_lon)


func _process(delta: float):
	if not _has_target:
		return

	var tm = get_node_or_null("/root/TimeManager")
	if not tm or tm.paused or tm.speed <= 0:
		return

	var sim_speed = float(tm.speed)
	var max_move_distance = (movement_speed * sim_speed * delta) / 1002.0 * (180.0 / PI)  # in Grad

	var current_pos = global_position.normalized()
	var target_pos = _lat_lon_to_vector3(_target_lat, _target_lon, 1002.0).normalized()
	var angle_to_target = acos(clampf(current_pos.dot(target_pos), -1.0, 1.0))

	if angle_to_target <= max_move_distance or angle_to_target < 0.001:
		global_position = target_pos * 1002.0
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
		global_position = new_dir * 1002.0

		var mag = global_position.length()
		current_lat = rad_to_deg(asin(global_position.y / mag))
		current_lon = rad_to_deg(atan2(global_position.x, global_position.z))

		# Nach Bewegung wieder radial ausrichten (falls nötig)
		var normal = global_position.normalized()
		look_at(global_position + normal * 50.0, Vector3.UP)


func _on_arrival():
	print("Einheit angekommen: ", entity_name)
	# TODO: später Formation, Supply etc.


func _lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)


# Hilfsfunktionen (für spätere Fenster etc.)
func get_display_name() -> String:
	return entity_name

func is_division() -> bool:
	return entity_type == "division"
