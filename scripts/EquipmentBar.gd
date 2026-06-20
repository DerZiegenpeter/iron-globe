extends Control

@onready var manpower_label: Label = $HBoxContainer/ManpowerLabel
@onready var buttons_container: HBoxContainer = $HBoxContainer/Buttons

@onready var equip_manager: Node = get_node("/root/EquipmentManager")

var equipment_window_scene = preload("res://scenes/ui/equipment_window.tscn")
var equipment_window_instance = null

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
	_create_category_buttons()
	update_manpower_display()


func _create_category_buttons():
	for cat in categories:
		var btn = Button.new()
		btn.text = cat
		btn.custom_minimum_size = Vector2(140, 28)
		btn.pressed.connect(_on_category_pressed.bind(cat))
		buttons_container.add_child(btn)


func update_manpower_display(nation: String = "GER"):
	if manpower_label:
		manpower_label.text = "Manpower: 2.480.000"


func _on_category_pressed(category: String):
	if equipment_window_instance == null:
		equipment_window_instance = equipment_window_scene.instantiate()
		get_tree().current_scene.add_child(equipment_window_instance)

	if equipment_window_instance and equipment_window_instance.has_method("open_for_category"):
		equipment_window_instance.open_for_category(category, "GER")
