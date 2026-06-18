extends Control

@onready var date_label: Label = $HBoxContainer/DateLabel

func _ready():
	# Warte kurz, bis alles geladen ist
	await get_tree().process_frame

	var tm = get_node_or_null("/root/TimeManager")

	if tm == null:
		print("❌ TimeManager nicht gefunden!")
		return

	print("✅ TimeManager erfolgreich gefunden!")

	# Verbindung herstellen
	if not tm.time_advanced.is_connected(_update_date):
		tm.time_advanced.connect(_update_date)

	_update_date(0)

	# Starte pausiert
	tm.paused = true
	tm.speed = 0

func _update_date(_days: int = 0):
	var tm = get_node_or_null("/root/TimeManager")
	if tm and date_label:
		date_label.text = tm.get_date_string()

func _on_pause_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.toggle_pause()
		print(">>> Pause gedrückt | speed =", tm.speed)

func _on_speed_1_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_speed(1)
		print(">>> Speed auf 1x gesetzt")

func _on_speed_2_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_speed(2)

func _on_speed_5_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_speed(5)

func _on_speed_10_pressed():
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.set_speed(10)
