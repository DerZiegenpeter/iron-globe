extends Control

@onready var date_label: Label = $HBoxContainer/DateLabel
@onready var pause_button: Button = $HBoxContainer/PauseButton
@onready var speed_1: Button = $HBoxContainer/Speed1Button
@onready var speed_2: Button = $HBoxContainer/Speed2Button
@onready var speed_5: Button = $HBoxContainer/Speed5Button
@onready var speed_10: Button = $HBoxContainer/Speed10Button

@onready var time_manager = get_node("/root/TimeManager")

func _ready():
	time_manager.time_advanced.connect(_update_date)
	_update_date(0)
	
	# Standard: Zeit ist pausiert
	time_manager.paused = true
	time_manager.speed = 0

func _update_date(_days):
	if date_label:
		date_label.text = time_manager.get_date_string()

func _on_pause_pressed():
	time_manager.toggle_pause()

func _on_speed_1_pressed():
	time_manager.set_speed(1)

func _on_speed_2_pressed():
	time_manager.set_speed(2)

func _on_speed_5_pressed():
	time_manager.set_speed(5)

func _on_speed_10_pressed():
	time_manager.set_speed(10)
