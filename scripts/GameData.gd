extends Node

var nations: Dictionary = {}                    # "IND" → volle Nation-Daten
var province_to_owner: Dictionary = {}          # int ID → "IND"
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
	
	var data = json.data.get("nations", [])
	for n in data:
		var code = str(n.get("short_name", n.get("code", n.get("id", "")))).to_upper().strip_edges()
		if code != "":
			nations[code] = n
			print("Nation geladen: ", code, " → ", n.get("name", ""))
	
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
		var owner = str(entry.get("owner", "NEU")).to_upper()
		var controller = str(entry.get("controller", owner)).to_upper()
		
		province_to_owner[pid] = owner
		province_to_controller[pid] = controller
	
	print("✅ Ownership geladen: ", province_to_owner.size(), " Provinzen")

func get_province_info(province_id: int, region_name: String = "") -> String:
	if province_id <= 0:
		return "ID: %s | Name: %s | Besitzer: Unbekannt" % [province_id, region_name]
	
	var owner_code = province_to_owner.get(province_id, "NEU")
	var nation = nations.get(owner_code, {})
	
	var owner_name = nation.get("name", "Unbekannt")
	
	return """=== Provinz Info ===
ID:          %d
Name:        %s
Owner:       %s (%s)
Controller:  %s (%s)
""" % [province_id, region_name, owner_name, owner_code, owner_name, owner_code]
