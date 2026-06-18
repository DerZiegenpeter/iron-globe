extends Control

@onready var date_label: Label = $HBoxContainer/DateLabel
@onready var hbox: HBoxContainer = $HBoxContainer

var tm: Node = null

func _ready():
	await get_tree().process_frame

	tm = get_node_or_null("/root/TimeManager")
	if tm == null:
		print("❌ TimeManager nicht gefunden!")
		return

	print("✅ TimeManager gefunden")

	# Datum aktualisieren
	if not tm.time_advanced.is_connected(_update_date):
		tm.time_advanced.connect(_update_date)
	_update_date(0)

	# === Buttons automatisch finden und verbinden (robust) ===
	for child in hbox.get_children():
		if child is Button:
			var btn = child as Button
			print("Button gefunden: ", btn.name)
			
			match btn.name:
				"PauseButton":
					btn.pressed.connect(_on_pause_pressed)
				"Speed1Button":
					btn.pressed.connect(_on_speed_1_pressed)
				"Speed2Button":
					btn.pressed.connect(_on_speed_2_pressed)
				"Speed5Button":
					btn.pressed.connect(_on_speed_5_pressed)
				"Speed10Button":
					btn.pressed.connect(_on_speed_10_pressed)

	# Start pausiert
	tm.set_speed(0)
	print(">>> TimeControl bereit (pausiert)")

func _update_date(_days: int = 0):
	if tm and date_label:
		date_label.text = tm.get_date_string()

func _on_pause_pressed():
	if tm:
		tm.toggle_pause()
		print(">>> PAUSE gedrückt → speed =", tm.speed, " paused =", tm.paused)

func _on_speed_1_pressed():
	if tm:
		print(">>> 1x gedrückt")
		tm.set_speed(1)

func _on_speed_2_pressed():
	if tm:
		print(">>> 2x gedrückt")
		tm.set_speed(2)

func _on_speed_5_pressed():
	if tm:
		print(">>> 5x gedrückt")
		tm.set_speed(5)

func _on_speed_10_pressed():
	if tm:
		print(">>> 10x gedrückt")
		tm.set_speed(10)
