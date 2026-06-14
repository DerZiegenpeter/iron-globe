extends Camera3D

@export var globe_radius: float = 1000.0
@export var start_radius: float = 2800.0
@export var sensitivity: float = 0.001
@export var min_zoom_speed: float = 20.0
@export var max_zoom_speed: float = 80.0
@export var zoom_smooth: float = 10.0
@export var min_distance: float = 1017.0
@export var max_distance: float = 3000.0

var yaw: float = 0.0
var pitch: float = 0.22
var target_yaw: float = 0.0
var target_pitch: float = 0.22
var target_radius: float = 2800.0
var current_radius: float = 2800.0
var mouse_delta := Vector2.ZERO

func _ready():
	Input.use_accumulated_input = false          # wichtig für präzisere Maus-Events
	current_radius = start_radius
	target_radius = start_radius
	target_yaw = yaw
	target_pitch = pitch
	update_position()

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		mouse_delta += event.relative

	if event is InputEventMouseButton:
		var zoom_amount = get_current_zoom_speed()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_radius = max(min_distance, target_radius - zoom_amount)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_radius = min(max_distance, target_radius + zoom_amount)

func _process(delta):
	# Maus-Delta direkt auf die Ziele anwenden
	if mouse_delta.length_squared() > 0.0:
		target_yaw -= mouse_delta.x * sensitivity
		target_pitch = clamp(target_pitch - mouse_delta.y * sensitivity * 0.5, -1.3, 1.3)
		mouse_delta = Vector2.ZERO

	# === Hier passiert das Glätten (das war vorher nicht da) ===
	yaw = lerp(yaw, target_yaw, 30.0 * delta)
	pitch = lerp(pitch, target_pitch, 30.0 * delta)

	current_radius = lerp(current_radius, target_radius, zoom_smooth * delta)
	update_position()

func get_current_zoom_speed() -> float:
	var t = inverse_lerp(min_distance, max_distance, current_radius)
	return lerp(min_zoom_speed, max_zoom_speed, t)

func update_position():
	var dir = Vector3(
		cos(yaw) * cos(pitch),
		sin(pitch),
		sin(yaw) * cos(pitch)
	).normalized()
	position = dir * current_radius
	look_at(Vector3.ZERO)
