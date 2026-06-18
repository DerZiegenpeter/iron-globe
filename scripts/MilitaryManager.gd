extends Node

@export var ground_entity_scene: PackedScene = preload("res://scenes/military/GroundEntity.tscn")

var entities: Dictionary = {}      # id → GroundEntity
var parent_map: Dictionary = {}    # child_id → parent_id

func _ready():
	print("=== MilitaryManager gestartet ===")
	load_order_of_battle()
	create_hierarchy_lines()

func load_order_of_battle():
	var path = "res://data/oob.json"
	if not FileAccess.file_exists(path):
		print("❌ oob.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var data = json.data.get("GER", {})

	# High Command
	if data.has("high_command"):
		var hc = data.high_command
		spawn(hc.id, hc, "high_command")
		for child_id in hc.get("children", []):
			parent_map[child_id] = hc.id

	for item in data.get("army_groups", []):
		spawn(item.id, item, "army_group")
		for child_id in item.get("children", []):
			parent_map[child_id] = item.id

	for item in data.get("armies", []):
		spawn(item.id, item, "army")
		for child_id in item.get("children", []):
			parent_map[child_id] = item.id

	for item in data.get("corps", []):
		spawn(item.id, item, "corps")
		for child_id in item.get("children", []):
			parent_map[child_id] = item.id

	for item in data.get("divisions", []):
		spawn(item.id, item, "division")
		for child_id in item.get("children", []):
			parent_map[child_id] = item.id

	for item in data.get("brigades", []):
		spawn(item.id, item, "brigade")
		for child_id in item.get("children", []):
			parent_map[child_id] = item.id

func spawn(id: String, data: Dictionary, type: String):
	if ground_entity_scene == null:
		print("❌ GroundEntity.tscn nicht gefunden!")
		return

	var entity = ground_entity_scene.instantiate()
	get_tree().current_scene.add_child(entity)
	entity.setup(data, type)
	entity._ready_after_add()

	entities[id] = entity
	print("✅", type.to_upper(), "gespawnt:", data.get("name", id))

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
			line.setup(parent_entity, child_entity, 18, 28.0)
		
		count += 1
	
	print("✅", count, "dynamische Hierarchy-Bögen erstellt (folgen den Einheiten).")
