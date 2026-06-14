extends Node

var nations: Dictionary = {}           # "IND" → Nation
var province_to_owner: Dictionary = {}     # int ID → "IND"
var province_to_controller: Dictionary = {}

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
	
	for n in json.data.get("nations", []):
		var code = n.get("short_name", "")
		if code:
			nations[code.to_upper()] = n
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
		province_to_owner[pid] = entry.get("owner", "NEU")
		province_to_controller[pid] = entry.get("controller", entry.get("owner", "NEU"))
	
	print("✅ Ownership geladen: ", province_to_owner.size(), " Provinzen")

func get_province_info(province_id: int, region_name: String = "") -> String:
	if province_id <= 0:
		return "=== Provinz Info ===\nID: %s\nName: %s\nOwner: Unbekannt\nController: Unbekannt" % [province_id, region_name]
	
	var owner_code = province_to_owner.get(province_id, "NEU")
	var nation = nations.get(owner_code, {})
	
	return """=== Provinz Info ===
ID:          %s
Name:        %s
Owner:       %s (%s)
Controller:  %s (%s)
""" % [province_id, region_name, nation.get("name", "Unbekannt"), owner_code, nation.get("name", "Unbekannt"), owner_code]
