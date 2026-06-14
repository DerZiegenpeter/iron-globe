extends Node

# Datenbanken
var nations: Dictionary = {}                    # nation_id (String) → Nation-Daten
var province_to_nation: Dictionary = {}         # province_id → nation_id (ursprünglich)
var current_owner: Dictionary = {}              # province_id → nation_id (aktuell, veränderbar)

signal ownership_changed(province_id: String, old_nation_id: int, new_nation_id: int)

func _ready():
	load_nations()
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

func load_ownership():
	var path = "res://data/ownership.json"
	if not FileAccess.file_exists(path):
		print("WARNUNG: ownership.json nicht gefunden!")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	province_to_nation = json.data.get("ownership", {})
	current_owner = province_to_nation.duplicate(true)
	print("✅ Besitzstände geladen: ", current_owner.size(), " Provinzen")

# Öffentliche Funktionen
func get_nation(province_id: String) -> Dictionary:
	var nation_id = str(current_owner.get(province_id, 0))
	return nations.get(nation_id, {
		"id": 0,
		"name": "Unbekannt",
		"short_name": "??",
		"color": "#888888"
	})

func change_ownership(province_id: String, new_nation_id: int) -> bool:
	if not current_owner.has(province_id):
		return false
	var old = current_owner[province_id]
	current_owner[province_id] = new_nation_id
	ownership_changed.emit(province_id, old, new_nation_id)
	print("Besitz gewechselt: ", province_id, " → Nation ", new_nation_id)
	return true

func get_province_owner(province_id: String) -> Dictionary:
	return get_nation(province_id)
