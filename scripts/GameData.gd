extends Node

var nations: Dictionary = {}
var current_owner: Dictionary = {}
var current_controller: Dictionary = {}

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
	
	for nation in json.data.get("nations", []):
		nations[str(nation.id)] = nation
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
	
	var data = json.data.get("ownership", {})
	for pid in data:
		current_owner[pid] = data[pid].owner
		current_controller[pid] = data[pid].controller
	print("✅ Ownership geladen: ", current_owner.size(), " Provinzen")

func get_nation(pid: Variant) -> Dictionary:
	var nation_id = str(current_owner.get(str(pid), "NONE"))
	return nations.get(nation_id, _default_nation())

func get_controller(pid: Variant) -> Dictionary:
	var nation_id = str(current_controller.get(str(pid), current_owner.get(str(pid), "NONE")))
	return nations.get(nation_id, _default_nation())

func _default_nation() -> Dictionary:
	return {"id": "NONE", "name": "Unbekannt", "color": "#888888"}

func get_click_info(province_id: Variant, region_name: String = "") -> String:
	var owner_data = get_nation(province_id)
	var ctrl_data = get_controller(province_id)
	return """=== Provinz Info ===
ID:          %s
Name:        %s
Owner:       %s
Controller:  %s
""" % [str(province_id), region_name, owner_data.get("name"), ctrl_data.get("name")]
