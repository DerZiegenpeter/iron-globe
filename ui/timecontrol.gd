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

	if not tm.time_advanced.is_connected(_update_date):
		tm.time_advanced.connect(_update_date)
	_update_date(0)

	for child in hbox.get_children():
		if child is Button:
			var btn = child as Button
			print("Button gefunden → Name: ", btn.name, " | Text: ", btn.text)
			btn.pressed.connect(_on_button_pressed.bind(btn))

	tm.set_speed(0)
	print(">>> TimeControl bereit (pausiert)")

func _update_date(_days: int = 0):
	if tm and date_label:
		date_label.text = tm.get_date_string()

func _on_button_pressed(btn: Button):
	var name = btn.name
	var text = btn.text.strip_edges().to_lower()
	print(">>> BUTTON GEKLICKT → Name: ", name, " | Text: ", btn.text)

	if "pause" in text or name == "PauseButton":
		if tm: tm.toggle_pause()
	elif "1x" in text or name == "Speed1Button":
		if tm: tm.set_speed(1)
	elif "2x" in text or name == "Speed2Button":
		if tm: tm.set_speed(2)
	elif "5x" in text or name == "Speed5Button":
		if tm: tm.set_speed(5)
	elif "10x" in text or name == "Speed10Button":
		if tm: tm.set_speed(10)

# === TASTATUR-STEUERUNG (funktioniert garantiert) ===
func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if tm:
					tm.toggle_pause()
				print(">>> TASTE: Pause/Play")
			KEY_1:
				if tm:
					tm.set_speed(1)
				print(">>> TASTE: 1x")
			KEY_2:
				if tm:
					tm.set_speed(2)
				print(">>> TASTE: 2x")
			KEY_3:
				if tm:
					tm.set_speed(5)
				print(">>> TASTE: 5x")
			KEY_4:
				if tm:
					tm.set_speed(10)
				print(">>> TASTE: 10x")
			KEY_0:
				if tm:
					tm.set_speed(0)
				print(">>> TASTE: Pause (0)")
