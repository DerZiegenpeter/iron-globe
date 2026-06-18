extends Node

var nations: Dictionary = {}                    # code → full nation data
var province_to_owner: Dictionary = {}          # province_id → owner_code (z.B. "IND")
var province_to_controller: Dictionary = {}

var selected_province: Dictionary = {}          # Für State-Selection Tracking + Deselect

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
			# print("Nation geladen: ", code, " → ", n.get("name", ""))  # optional leise
	
	print("✅ Nationen geladen: ", nations.size())

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
	
	print("✅ Ownership geladen: ", province_to_owner.size(), " Provinzen")

func get_province_info(province_id: int, region_name: String = "") -> Dictionary:
	if province_id <= 0:
		return {
			"province_id": province_id, 
			"name": region_name if region_name != "" else "Unbekannt", 
			"owner": "Unbekannt", 
			"owner_code": "NEU",
			"controller": "Unbekannt",
			"controller_code": "NEU",
			"color": "#555555"
		}
	
	var owner_code = province_to_owner.get(province_id, "NEU")
	var nation = nations.get(owner_code, {})
	
	var owner_name = nation.get("name", "Unbekannt")
	var color_hex = nation.get("color", "#555555")
	
	var controller_code = province_to_controller.get(province_id, owner_code)
	var controller_nation = nations.get(controller_code, {})
	var controller_name = controller_nation.get("name", controller_code)
	
	return {
		"province_id": province_id,
		"name": region_name if region_name != "" else "Unbekannt",
		"owner": owner_name,
		"owner_code": owner_code,
		"controller": controller_name,
		"controller_code": controller_code,
		"color": color_hex
	}

# === STATE SELECTION (wird von ClickHandler aufgerufen) ===
func select_province(province_id: int, province_name: String, info: Dictionary = {}):
	selected_province = {
		"id": province_id,
		"name": province_name,
		"info": info
	}
	
	print("═══════════════════════════════════════")
	print("=== STATE / PROVINZ AUSGEWÄHLT ===")
	print("Name: ", province_name, " (ID: ", province_id, ")")
	if not info.is_empty():
		print("Owner:     ", info.get("owner", "?"), " (", info.get("owner_code", "?"), ")")
		print("Controller:", info.get("controller", "?"), " (", info.get("controller_code", "?"), ")")
		if info.has("color"):
			print("Color:     ", info.get("color"))
	print("═══════════════════════════════════════")

func deselect_province():
	if selected_province.is_empty():
		return
	print("═══════════════════════════════════════")
	print("=== STATE DESELECTED: ", selected_province.get("name", ""), " (ID: ", selected_province.get("id", 0), ") ===")
	print("═══════════════════════════════════════")
	selected_province.clear()
