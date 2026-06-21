extends Node

@export var ground_entity_scene: PackedScene = preload("res://scenes/military/GroundEntity.tscn")

var entities: Dictionary = {}
var parent_map: Dictionary = {}

func _ready():
	print("=== MilitaryManager gestartet ===")
	load_order_of_battle()
	create_hierarchy_lines()

func load_order_of_battle():
	var path = "res://data/oob.json"
	if not FileAccess.file_exists(path):
		print("oob.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	for nation_code in json.data.keys():
		if nation_code == "metadata":
			continue

		var nation_data = json.data.get(nation_code, {})
		if not nation_data is Dictionary:
			continue

		print("Lade OOB für:", nation_code)

		# Combat Units (Divisionen + Brigaden)
		var combat_units = []
		combat_units += nation_data.get("divisions", [])
		combat_units += nation_data.get("brigades", [])

		for item in combat_units:
			if item is Dictionary and item.has("id"):
				spawn_combat_unit(item, nation_code)

		# Higher Commands
		if nation_data.has("high_command"):
			var hc = nation_data.high_command
			if hc is Dictionary:
				spawn_simple_unit(hc, "high_command", nation_code)

		for item in nation_data.get("army_groups", []):
			if item is Dictionary: spawn_simple_unit(item, "army_group", nation_code)
		for item in nation_data.get("armies", []):
			if item is Dictionary: spawn_simple_unit(item, "army", nation_code)
		for item in nation_data.get("corps", []):
			if item is Dictionary: spawn_simple_unit(item, "corps", nation_code)


func spawn_combat_unit(data: Dictionary, nation_code: String):
	if ground_entity_scene == null:
		return

	var entity = ground_entity_scene.instantiate()
	get_tree().current_scene.add_child(entity)

	# Manuelle Initialisierung (ohne setup() → kein Crash)
	entity.name = data.get("name", data.get("id", "Unit"))

	# Position setzen (wichtig für Sichtbarkeit)
	if data.has("position") and data.position is Array and data.position.size() >= 3:
		entity.global_position = Vector3(
			data.position[0],
			data.position[1],
			data.position[2]
		)

	entity.set_meta("unit_data", data)
	entity.set_meta("nation_code", nation_code)
	entity.set_meta("unit_type", data.get("type", "division"))

	entities[data.id] = entity
	print("COMBAT UNIT:", data.get("name", data.id), " | Nation:", nation_code)


func spawn_simple_unit(data: Dictionary, type: String, nation_code: String):
	if ground_entity_scene == null:
		return

	var entity = ground_entity_scene.instantiate()
	get_tree().current_scene.add_child(entity)

	entity.name = data.get("name", data.get("id", type))

	if data.has("position") and data.position is Array and data.position.size() >= 3:
		entity.global_position = Vector3(
			data.position[0],
			data.position[1],
			data.position[2]
		)

	entity.set_meta("unit_data", data)
	entity.set_meta("unit_type", type)
	entity.set_meta("nation_code", nation_code)

	entities[data.id] = entity
	print(type.to_upper(), ":", data.get("name", data.id))


func create_hierarchy_lines():
	print("=== Hierarchy Lines später ===")
