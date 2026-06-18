extends Node

var pops_by_state: Dictionary = {}   # state_id -> Array[Pop]
var all_pops: Array[Pop] = []

func _ready():
	load_initial_pops()

func load_initial_pops():
	var path = "res://data/initial_pops.json"
	if not FileAccess.file_exists(path):
		print("❌ initial_pops.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	pops_by_state.clear()
	all_pops.clear()

	for entry in json.data.get("pops", []):
		var pop = Pop.new(
			entry.get("state_id", 0),
			entry.get("profession", ""),
			entry.get("ethnicity", ""),
			entry.get("culture", ""),
			entry.get("religion", ""),
			entry.get("size", 0)
		)
		
		if not pops_by_state.has(pop.state_id):
			pops_by_state[pop.state_id] = []
		
		pops_by_state[pop.state_id].append(pop)
		all_pops.append(pop)

	print("✅ Pops geladen. Anzahl States mit Pops:", pops_by_state.size())

func get_pops_in_state(state_id: int) -> Array:
	return pops_by_state.get(state_id, [])

func get_total_population(state_id: int) -> int:
	var total = 0
	for pop in get_pops_in_state(state_id):
		total += pop.size
	return total

func get_pop_summary(state_id: int) -> String:
	var pops = get_pops_in_state(state_id)
	if pops.is_empty():
		return "Keine Pops in diesem State."
	
	var summary = ""
	for pop in pops:
		summary += "%s %s (%s): %s | " % [
			pop.ethnicity.capitalize(),
			pop.profession,
			pop.culture,
			pop.size
		]
	return summary.trim_suffix(" | ")
