extends Control

@onready var date_label: Label = $HBoxContainer/DateLabel

@onready var pause_button: Button = $HBoxContainer/PauseButton
@onready var speed_1_button: Button = $HBoxContainer/Speed1Button
@onready var speed_2_button: Button = $HBoxContainer/Speed2Button
@onready var speed_5_button: Button = $HBoxContainer/Speed5Button
@onready var speed_10_button: Button = $HBoxContainer/Speed10Button

func _ready():
	await get_tree().process_frame

	var tm = get_node_or_null("/root/TimeManager")
	if tm == null:
		print("❌ TimeManager nicht gefunden!")
		return

	print("✅ TimeManager erfolgreich gefunden!")

	# Signal für Datums-Update
	if not tm.time_advanced.is_connected(_update_date):
		tm.time_advanced.connect(_update_date)

	_update_date(0)

	# Buttons explizit verbinden (das war das Problem!)
	pause_button.pressed.connect(_on_pause_pressed)
	speed_1_button.pressed.connect(_on_speed_1_pressed)
	speed_2_button.pressed.connect(_on_speed_2_pressed)
	speed_5_button.pressed.connect(_on_speed_5_pressed)
	speed_10_button.pressed.connect(_on_speed_10_pressed)

	# Start pausiert
	tm.set_speed(0)

func _update_date(_days: int = 0):
	var tm = get_node_or_null("/root/TimeManager")
	if tm and date_label:
		date_label.text = tm.get_date_string()

func _on_pause_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.toggle_pause()
		print(">>> Pause/Play | speed =", tm.speed)

func _on_speed_1_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_speed(1)
		print(">>> Speed 1x")

func _on_speed_2_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_speed(2)
		print(">>> Speed 2x")

func _on_speed_5_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_speed(5)
		print(">>> Speed 5x")

func _on_speed_10_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_speed(10)
		print(">>> Speed 10x")
