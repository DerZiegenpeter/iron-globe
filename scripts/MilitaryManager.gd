extends Node
class_name MilitaryManager

@export var division_scene: PackedScene = preload("res://scenes/military/Division.tscn")

var divisions: Dictionary = {}   # id -> Division Node

func _ready():
	load_order_of_battle()

func load_order_of_battle():
	var path = "res://data/oob.json"
	if not FileAccess.file_exists(path):
		print("❌ oob.json nicht gefunden!")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var data = json.data
	
	for nation_code in data.keys():
		var nation_data = data[nation_code]
		var division_list = nation_data.get("divisions", [])
		
		for div_data in division_list:
			spawn_division(nation_code, div_data)

func spawn_division(nation_code: String, div_data: Dictionary):
	if division_scene == null:
		print("❌ Division.tscn nicht gefunden!")
		return
	
	var division = division_scene.instantiate()
	division.setup(div_data)
	division.nation_code = nation_code   # falls du es brauchst
	
	# Hier später: In einen "Units"-Node packen (siehe unten)
	get_tree().current_scene.add_child(division)
	
	divisions[div_data.get("id", "")] = division
	print("✅ Division gespawnt:", div_data.get("name", "Unbekannt"))
