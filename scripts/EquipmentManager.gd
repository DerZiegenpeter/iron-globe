extends Node

# ========================== DATEN ==========================
var equipment_types: Dictionary = {}
var national_stockpiles: Dictionary = {}   # nation_code -> { equipment_id: amount }

signal equipment_stockpile_changed(nation_code: String, equipment_id: String, new_amount: int)


func _ready():
	load_equipment_types()
	_initialize_starting_stockpiles()


func load_equipment_types():
	var path = "res://data/equipment_types.json"
	if not FileAccess.file_exists(path):
		print("❌ equipment_types.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	equipment_types = json.data
	print("✅ Equipment Types geladen:", equipment_types.keys())


func _initialize_starting_stockpiles():
	# Deutschland (GER)
	national_stockpiles["GER"] = {
		"rifle": 125000,
		"machine_gun": 8200,
		"mortar_81mm": 1450,
		"atgm": 980,
		"mbt": 1250,
		"ifv": 680,
		"artillery_155mm": 420,
		"apc": 890
	}

	# Polen (POL)
	national_stockpiles["POL"] = {
		"rifle": 98000,
		"machine_gun": 6100,
		"mortar_81mm": 980,
		"atgm": 620,
		"mbt": 780,
		"ifv": 410,
		"artillery_155mm": 290,
		"apc": 520
	}

	print("✅ Start-Ausrüstung für GER und POL initialisiert")


# ========================== BERECHNUNGEN ==========================

func get_required_equipment(composition: Array) -> Dictionary:
	var required := {}

	for entry in composition:
		var bat_type = entry.get("type", "")
		var amount = entry.get("amount", 1)

		var bat_data = get_battalion_data(bat_type)
		if bat_data.is_empty():
			continue

		var requirements = bat_data.get("equipment_requirements", {})
		for equip_id in requirements:
			var needed_per_bat = requirements[equip_id]
			var total_needed = needed_per_bat * amount

			if not required.has(equip_id):
				required[equip_id] = 0
			required[equip_id] += total_needed

	return required


func get_battalion_data(battalion_type: String) -> Dictionary:
	var path = "res://data/battalion_types.json"
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	return json.data.get(battalion_type, {})


# ========================== LAGERBESTAND ==========================

func get_stockpile(nation_code: String) -> Dictionary:
	return national_stockpiles.get(nation_code, {})


func add_to_stockpile(nation_code: String, equipment_id: String, amount: int):
	if not national_stockpiles.has(nation_code):
		national_stockpiles[nation_code] = {}

	if not national_stockpiles[nation_code].has(equipment_id):
		national_stockpiles[nation_code][equipment_id] = 0

	national_stockpiles[nation_code][equipment_id] += amount
	equipment_stockpile_changed.emit(nation_code, equipment_id, national_stockpiles[nation_code][equipment_id])


func remove_from_stockpile(nation_code: String, equipment_id: String, amount: int) -> bool:
	var stock = national_stockpiles.get(nation_code, {})
	if not stock.has(equipment_id) or stock[equipment_id] < amount:
		return false

	stock[equipment_id] -= amount
	equipment_stockpile_changed.emit(nation_code, equipment_id, stock[equipment_id])
	return true


func has_enough_equipment(nation_code: String, required: Dictionary) -> bool:
	var stock = get_stockpile(nation_code)
	for equip_id in required:
		var needed = required[equip_id]
		var available = stock.get(equip_id, 0)
		if available < needed:
			return false
	return true
