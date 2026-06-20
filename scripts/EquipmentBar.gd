extends Control

@onready var manpower_label: Label = $HBoxContainer/ManpowerLabel
@onready var buttons_container: HBoxContainer = $HBoxContainer/Buttons

var equip_manager: EquipmentManager
var equipment_window: EquipmentWindow

var categories = [
	"Infantry Weapons",
	"Support Weapons",
	"Armor",
	"Artillery",
	"Anti-Tank",
	"Anti-Air",
	"Vehicles & Mobility",
	"Engineering & Logistics"
]


func _ready():
	equip_manager = get_node_or_null("/root/EquipmentManager")
	equipment_window = get_node_or_null("/root/EquipmentWindow")  # Will be set from main scene if needed

	# Create category buttons
	for cat in categories:
		var btn = Button.new()
		btn.text = cat
		btn.custom_minimum_size = Vector2(140, 28)
		btn.pressed.connect(_on_category_pressed.bind(cat))
		buttons_container.add_child(btn)

	update_manpower_display()


func update_manpower_display(nation: String = "GER"):
	# For now static - later connect to actual manpower calculation
	if manpower_label:
		manpower_label.text = "Manpower: 2.480.000"


func _on_category_pressed(category: String):
	if equipment_window:
		equipment_window.open_for_category(category, "GER")
	else:
		print("EquipmentWindow not found!")
