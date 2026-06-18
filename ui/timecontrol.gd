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
			print("Button verbunden: ", btn.name)
			btn.pressed.connect(_on_button_pressed.bind(btn))

	tm.set_speed(0)
	print(">>> TimeControl bereit")

func _update_date(_days: int = 0):
	if tm and date_label:
		date_label.text = tm.get_date_string()

func _on_button_pressed(btn: Button):
	print(">>> BUTTON GEKLICKT: ", btn.name, " | Text: ", btn.text)
	var text = btn.text.strip_edges().to_lower()

	if "pause" in text or btn.name == "PauseButton":
		if tm: tm.toggle_pause()
	elif "1x" in text or btn.name == "Speed1Button":
		if tm: tm.set_speed(1)
	elif "2x" in text or btn.name == "Speed2Button":
		if tm: tm.set_speed(2)
	elif "5x" in text or btn.name == "Speed5Button":
		if tm: tm.set_speed(5)
	elif "10x" in text or btn.name == "Speed10Button":
		if tm: tm.set_speed(10)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		print(">>> TASTE gedrückt: ", event.keycode)
		match event.keycode:
			KEY_SPACE:
				if tm: tm.toggle_pause()
			KEY_1:
				if tm: tm.set_speed(1)
			KEY_2:
				if tm: tm.set_speed(2)
			KEY_3:
				if tm: tm.set_speed(5)
			KEY_4:
				if tm: tm.set_speed(10)
			KEY_0:
				if tm: tm.set_speed(0)
