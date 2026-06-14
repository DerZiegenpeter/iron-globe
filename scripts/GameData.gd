extends Node

# Datenbanken
var nations: Dictionary = {}                    # nation_id → Nation-Daten
var states: Dictionary = {}                     # province_id → State-Daten (mit owner/controller)

signal ownership_changed(province_id: String, old_nation_id: String, new_nation_id: String)

func _ready():
	load_nations()
	load_states()
	load_ownership()

func load_nations():
	var path = "res://data/nations.json"
	if not FileAccess.file_exists(path):
		print("WARNUNG: nations.json nicht gefunden!")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var data = json.data
	for nation in data.get("nations", []):
		nations[str(nation.id)] = nation
	print("✅ Nationen geladen: ", nations.size())

func load_states():
	var path = "res://data/states.json"
	if not FileAccess.file_exists(path):
		print("WARNUNG: states.json nicht gefunden!")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var data = json.data
	for state in data.get("states", []):
		states[str(state.id)] = state
	print("✅ Staaten geladen: ", states.size())

func load_ownership():
	var path = "res://data/ownership.json"
	if not FileAccess.file_exists(path):
		print("WARNUNG: ownership.json nicht gefunden!")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	# ownership.json hat aktuell noch nicht die volle Struktur, daher nutzen wir states.json als Hauptquelle
	print("✅ Besitzstände geladen.")

# Hauptfunktion für ClickHandler
func get_province_info(province_id: String) -> Dictionary:
	var state = states.get(province_id, null)
	if not state:
		return {"name": "Unbekannt", "owner": "??", "controller": "??"}
	
	var owner_nation = nations.get(state.owner, {"name": "Unbekannt", "id": state.owner})
	var controller_nation = nations.get(state.controller, {"name": "Unbekannt", "id": state.controller})
	
	return {
		"id": province_id,
		"name": state.name,
		"owner_id": state.owner,
		"owner_name": owner_nation.name,
		"controller_id": state.controller,
		"controller_name": controller_nation.name
	}
