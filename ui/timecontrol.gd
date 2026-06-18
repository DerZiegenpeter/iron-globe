extends Control

@onready var date_label: Label = $HBoxContainer/DateLabel
@onready var pause_button: Button = $HBoxContainer/PauseButton
@onready var speed_1: Button = $HBoxContainer/Speed1Button
@onready var speed_2: Button = $HBoxContainer/Speed2Button
@onready var speed_5: Button = $HBoxContainer/Speed5Button
@onready var speed_10: Button = $HBoxContainer/Speed10Button

func _ready():
	# Warte kurz, falls TimeManager noch nicht bereit ist
	await get_tree().process_frame

	var time_manager = get_node_or_null("/root/TimeManager")
	
	if time_manager:
		time_manager.time_advanced.connect(_update_date)
		_update_date(0)
		
		# Wichtig: Zeit startet pausiert
		time_manager.paused = true
		time_manager.speed = 0
	else:
		print("FEHLER: TimeManager nicht als Autoload gefunden!")

func _update_date(_days):
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and date_label:
		date_label.text = time_manager.get_date_string()

func _on_pause_pressed():
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.toggle_pause()

func _on_speed_1_pressed():
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.set_speed(1)

func _on_speed_2_pressed():
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.set_speed(2)

func _on_speed_5_pressed():
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.set_speed(5)

func _on_speed_10_pressed():
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.set_speed(10)
