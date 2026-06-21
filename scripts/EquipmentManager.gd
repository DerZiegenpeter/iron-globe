extends Node

var equipment_types: Dictionary = {}
var national_stockpiles: Dictionary = {}

signal equipment_stockpile_changed(nation_code: String, equipment_id: String, new_amount: int)

func _ready():
	load_equipment_types()
	_initialize_starting_stockpiles()

func load_equipment_types():
	var path = "res://data/equipment_types.json"
	if not FileAccess.file_exists(path):
		print("equipment_types.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	equipment_types = json.data
	print("Equipment Types geladen:", equipment_types.keys())


func _initialize_starting_stockpiles():
	# Angepasst an die IDs aus equipment_types.json
	national_stockpiles["GER"] = {
		"bolt_action_rifles": 125000,
		"light_tanks": 820,
		"medium_tanks": 430,
		"heavy_tanks": 180,
		"artillery_105mm": 420,
		"artillery_155mm": 180,
		"anti_tank_guns": 980,
		"anti_air_guns": 620,
		"trucks": 12500,
		"half_tracks": 3400
	}

	national_stockpiles["POL"] = {
		"bolt_action_rifles": 98000,
		"light_tanks": 180,
		"artillery_105mm": 290,
		"anti_tank_guns": 620,
		"trucks": 4800
	}

	print("Start-Stockpiles initialisiert")


func get_stockpile(nation_code: String) -> Dictionary:
	return national_stockpiles.get(nation_code, {})


func get_equipment_category(equip_id: String) -> String:
	if equipment_types.has(equip_id):
		return equipment_types[equip_id].get("category", "")
	return ""


func get_equipment_display_name(equip_id: String) -> String:
	if equipment_types.has(equip_id):
		return equipment_types[equip_id].get("display_name", equip_id)
	return equip_id


func add_to_stockpile(nation_code: String, equipment_id: String, amount: int):
	if not national_stockpiles.has(nation_code):
		national_stockpiles[nation_code] = {}
	if not national_stockpiles[nation_code].has(equipment_id):
		national_stockpiles[nation_code][equipment_id] = 0

	national_stockpiles[nation_code][equipment_id] += amount
	equipment_stockpile_changed.emit(nation_code, equipment_id, national_stockpiles[nation_code][equipment_id])
