extends Node

@export var ground_entity_scene: PackedScene = preload("res://scenes/military/GroundEntity.tscn")

var entities: Dictionary = {}

func _ready():
	print("=== MilitaryManager gestartet ===")
	load_order_of_battle()

func load_order_of_battle():
	var path = "res://data/oob.json"
	if not FileAccess.file_exists(path):
		print("❌ oob.json nicht gefunden")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var data = json.data

	# High Command
	if data.has("high_command"):
		spawn_entity("high_command", data.high_command, "high_command")

	# Army Groups
	for item in data.get("army_groups", []):
		spawn_entity(item.id, item, "army_group")

	# Armies
	for item in data.get("armies", []):
		spawn_entity(item.id, item, "army")

	# Corps
	for item in data.get("corps", []):
		spawn_entity(item.id, item, "corps")

	# Divisions
	for item in data.get("divisions", []):
		spawn_entity(item.id, item, "division")

	# Brigades
	for item in data.get("brigades", []):
		spawn_entity(item.id, item, "brigade")

func spawn_entity(id: String, data: Dictionary, type: String):
	if ground_entity_scene == null:
		print("❌ GroundEntity.tscn nicht gefunden!")
		return

	var entity = ground_entity_scene.instantiate()
	get_tree().current_scene.add_child(entity)
	entity.setup(data, type)
	entity._ready_after_add()

	entities[id] = entity
	print("✅", type.capitalize(), "gespawnt:", data.get("name", id))
