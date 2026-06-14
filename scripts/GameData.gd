extends Node

var nations: Dictionary = {}                    # nation_id ("IDN_") → Nation
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
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		print("❌ JSON Parse Fehler in nations.json!")
		return
	
	for nation in json.data.get("nations", []):
		var nid = str(nation.get("id"))
		nations[nid] = nation
		# Debug: erste paar ausgeben
		if nations.size() <= 5:
			print("Nation geladen: ", nid, " = ", nation.get("name"))
	
	print("✅ Nationen geladen: ", nations.size(), " Stück")

func load_ownership():
	var path = "res://data/ownership.json"
	if not FileAccess.file_exists(path):
		print("WARNUNG: ownership.json nicht gefunden!")
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var data = json.data.get("ownership", {})
	current_owner = data.duplicate(true)
	current_controller = data.duplicate(true)
	print("✅ Ownership geladen: ", current_owner.size(), " Provinzen")

func get_nation(pid: Variant) -> Dictionary:
	var province_id = str(pid)
	var nation_id = str(current_owner.get(province_id, "NONE"))
	return nations.get(nation_id, _default_nation())

func get_controller(pid: Variant) -> Dictionary:
	var province_id = str(pid)
	var nation_id = str(current_controller.get(province_id, current_owner.get(province_id, "NONE")))
	return nations.get(nation_id, _default_nation())

func _default_nation() -> Dictionary:
	return {
		"id": "NONE",
		"name": "Unbekannt",
		"short_name": "??",
		"color": "#888888"
	}

func get_click_info(province_id: Variant, region_name: String = "") -> String:
	var owner = get_nation(province_id)
	var ctrl = get_controller(province_id)
	return """=== Provinz Info ===
ID:          %s
Name:        %s
Owner:       %s (%s)
Controller:  %s (%s)
""" % [str(province_id), region_name, owner.get("name"), owner.get("short_name", owner.get("name")), ctrl.get("name"), ctrl.get("short_name", ctrl.get("name"))]
