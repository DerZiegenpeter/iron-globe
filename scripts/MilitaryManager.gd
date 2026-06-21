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
				for child_id in hc.get("children", []):
					parent_map[child_id] = hc.id

		for item in nation_data.get("army_groups", []):
			if item is Dictionary: 
				spawn_simple_unit(item, "army_group", nation_code)
				for child_id in item.get("children", []):
					parent_map[child_id] = item.id

		for item in nation_data.get("armies", []):
			if item is Dictionary: 
				spawn_simple_unit(item, "army", nation_code)
				for child_id in item.get("children", []):
					parent_map[child_id] = item.id

		for item in nation_data.get("corps", []):
			if item is Dictionary: 
				spawn_simple_unit(item, "corps", nation_code)
				for child_id in item.get("children", []):
					parent_map[child_id] = item.id


func spawn_combat_unit(data: Dictionary, nation_code: String):
	if ground_entity_scene == null:
		return

	var entity = ground_entity_scene.instantiate()

	# WICHTIG: Name, Position und Meta VOR add_child() setzen!
	# Sonst läuft _ready() mit falschen Werten und Einheiten stapeln sich im Weltraum.
	entity.name = data.get("name", data.get("id", "Unit"))
	if data.has("position") and data.position is Array and data.position.size() >= 3:
		entity.global_position = Vector3(
			data.position[0],
			data.position[1],
			data.position[2]
		)
	entity.set_meta("unit_data", data)
	entity.set_meta("nation_code", nation_code)
	entity.set_meta("unit_type", data.get("type", "division"))

	get_tree().current_scene.add_child(entity)

	entities[data.id] = entity
	print("COMBAT UNIT:", data.get("name", data.id), " | Nation:", nation_code)


func spawn_simple_unit(data: Dictionary, type: String, nation_code: String):
	if ground_entity_scene == null:
		return

	var entity = ground_entity_scene.instantiate()

	# WICHTIG: Name, Position und Meta VOR add_child() setzen!
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

	get_tree().current_scene.add_child(entity)

	entities[data.id] = entity
	print(type.to_upper(), ":", data.get("name", data.id))


func create_hierarchy_lines():
	print("=== Erstelle dynamische OOB Hierarchy Lines ===")
	
	var lines_container = Node3D.new()
	lines_container.name = "HierarchyLines"
	get_tree().current_scene.add_child(lines_container)
	
	var count = 0
	
	for child_id in parent_map.keys():
		var parent_id = parent_map[child_id]
		if not entities.has(child_id) or not entities.has(parent_id):
			continue
		
		var child_entity = entities[child_id]
		var parent_entity = entities[parent_id]
		
		var line = MeshInstance3D.new()
		line.name = "Line_%s→%s" % [parent_id, child_id]
		lines_container.add_child(line)
		
		line.set_script(load("res://scripts/military/HierarchyLine.gd"))
		
		if line.has_method("setup"):
			line.setup(parent_entity, child_entity, 18, 32.0)
		
		count += 1
	
	print("✅", count, "dynamische Hierarchy-Bögen erstellt (folgen den Einheiten).")
