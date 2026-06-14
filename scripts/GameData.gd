extends Node

var nations: Dictionary = {}                    # "IDN" → Nation
var current_owner: Dictionary = {}              # province_id (Zahl als String) → nation_id
var current_controller: Dictionary = {}

func _ready():
	load_nations()
	load_ownership_from_states()   # NEU: direkt aus states.json lesen

func load_nations():
	var path = "res://data/nations.json"
	if not FileAccess.file_exists(path):
		print("❌ nations.json nicht gefunden!")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	for nation in json.data.get("nations", []):
		var nid = str(nation.get("id")).replace("_", "")   # _ entfernen
		nations[nid] = nation
	print("✅ Nationen geladen: ", nations.size())

# NEU: Owner/Controller direkt aus states.json laden
func load_ownership_from_states():
	var path = "res://data/states.json"
	if not FileAccess.file_exists(path):
		print("❌ states.json nicht gefunden!")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var states = json.data.get("states", [])
	for state in states:
		var pid = str(state.get("id"))
		var owner_id = str(state.get("owner", state.get("nation", "NONE"))).replace("_", "")
		var controller_id = str(state.get("controller", owner_id)).replace("_", "")
		
		current_owner[pid] = owner_id
		current_controller[pid] = controller_id
	
	print("✅ Ownership aus states.json geladen: ", current_owner.size(), " Provinzen")

func get_nation(pid: Variant) -> Dictionary:
	var nation_id = str(current_owner.get(str(pid), "NONE"))
	return nations.get(nation_id, _default_nation())

func get_controller(pid: Variant) -> Dictionary:
	var nation_id = str(current_controller.get(str(pid), current_owner.get(str(pid), "NONE")))
	return nations.get(nation_id, _default_nation())

func _default_nation() -> Dictionary:
	return {"id": "NONE", "name": "Unbekannt", "short_name": "??", "color": "#888888"}

func get_click_info(province_id: Variant, region_name: String = "") -> String:
	var owner = get_nation(province_id)
	var ctrl = get_controller(province_id)
	return """=== Provinz Info ===
ID:          %s
Name:        %s
Owner:       %s (%s)
Controller:  %s (%s)
""" % [str(province_id), region_name, owner.get("name"), owner.get("short_name", "?"), ctrl.get("name"), ctrl.get("short_name", "?")]
