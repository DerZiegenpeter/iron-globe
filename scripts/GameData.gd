extends Node

var nations: Dictionary = {}
var province_to_owner: Dictionary = {}
var province_to_controller: Dictionary = {}
var selected_province: Dictionary = {}

@onready var pop_manager: Node = get_node_or_null("/root/PopManager")

signal state_selected(info: Dictionary)
signal state_deselected
signal unit_selected(entity: GroundEntity)

func _ready():
	load_nations()
	load_ownership()

func load_nations():
	var path = "res://data/nations.json"
	if not FileAccess.file_exists(path):
		print("❌ nations.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var data = json.data.get("nations", [])
	for n in data:
		var code = str(n.get("id", n.get("short_name", n.get("code", "")))).to_upper().strip_edges()
		if code != "":
			nations[code] = n

	print("✅ Nationen geladen:", nations.size())

func load_ownership():
	var path = "res://data/ownership.json"
	if not FileAccess.file_exists(path):
		print("❌ ownership.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	province_to_owner.clear()
	province_to_controller.clear()

	for entry in json.data.get("ownership", []):
		var pid = entry.get("id", 0) as int
		if pid <= 0: continue
		
		var owner_code = str(entry.get("owner", "NEU")).to_upper()
		var controller = str(entry.get("controller", owner_code)).to_upper()

		province_to_owner[pid] = owner_code
		province_to_controller[pid] = controller

	print("✅ Ownership geladen:", province_to_owner.size(), "Provinzen")

func get_province_info(province_id: int, region_name: String = "") -> Dictionary:
	if province_id <= 0:
		return {
			"province_id": province_id,
			"name": region_name if region_name != "" else "Unbekannt",
			"owner": "Unbekannt",
			"owner_code": "NEU",
			"controller": "Unbekannt",
			"controller_code": "NEU",
			"population": 0,
			"pops": "Keine Daten"
		}

	var owner_code = province_to_owner.get(province_id, "NEU")
	var nation = nations.get(owner_code, {})
	var owner_name = nation.get("name", "Unbekannt")
	var color_hex = nation.get("color", "#555555")

	var controller_code = province_to_controller.get(province_id, owner_code)
	var controller_nation = nations.get(controller_code, {})
	var controller_name = controller_nation.get("name", controller_code)

	var population = 0
	var pop_summary = "Keine Pops geladen"

	if pop_manager:
		population = pop_manager.get_total_population(province_id)
		pop_summary = pop_manager.get_pop_summary(province_id)

	return {
		"province_id": province_id,
		"name": region_name if region_name != "" else "Unbekannt",
		"owner": owner_name,
		"owner_code": owner_code,
		"controller": controller_name,
		"controller_code": controller_code,
		"color": color_hex,
		"population": population,
		"pops": pop_summary
	}

func select_province(province_id: int, province_name: String, info: Dictionary = {}):
	selected_province = {
		"id": province_id,
		"name": province_name,
		"info": info
	}

	state_selected.emit(info)

	print("═══════════════════════════════════════")
	print("=== STATE AUSGEWÄHLT ===")
	print("Name: %s (ID: %d)" % [province_name, province_id])

	if not info.is_empty():
		print("Owner:      ", info.get("owner", "?"), " (", info.get("owner_code", "?"), ")")
		print("Controller: ", info.get("controller", "?"), " (", info.get("controller_code", "?"), ")")
		print("Bevölkerung:", info.get("population", 0))
		print("Pops:       ", info.get("pops", "Keine Daten"))
	print("═══════════════════════════════════════")

func deselect_province():
	if selected_province.is_empty():
		return
	
	state_deselected.emit()
	
	print("=== STATE DESELECTED: %s (ID: %d) ===" % [selected_province.get("name", ""), selected_province.get("id", 0)])
	selected_province.clear()
