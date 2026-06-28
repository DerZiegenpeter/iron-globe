# scripts/military/DiplomacyManager.gd
# Vollständiges DiplomacyManager-Script mit Signalen
extends Node

signal war_declared(nation_a: String, nation_b: String)
signal peace_made(nation_a: String, nation_b: String)

var wars: Dictionary = {}
var alliances: Dictionary = {}
var guarantees: Dictionary = {}

func _ready():
	load_diplomacy()
	print("=== DiplomacyManager gestartet ===")

func load_diplomacy():
	var path = "res://data/diplomacy.json"
	if not FileAccess.file_exists(path):
		print("WARNING: diplomacy.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		print("Fehler beim Parsen von diplomacy.json")
		return

	var data = json.data
	wars = data.get("wars", {})
	alliances = data.get("alliances", {})
	guarantees = data.get("guarantees", {})

	print("Diplomacy geladen. Aktuelle Kriege: ", wars)

func is_at_war(nation_a: String, nation_b: String) -> bool:
	if wars.has(nation_a):
		return nation_b in wars[nation_a]
	return false

func declare_war(nation_a: String, nation_b: String):
	if not wars.has(nation_a):
		wars[nation_a] = []
	if not wars.has(nation_b):
		wars[nation_b] = []

	if nation_b not in wars[nation_a]:
		wars[nation_a].append(nation_b)
	if nation_a not in wars[nation_b]:
		wars[nation_b].append(nation_a)

	print("Krieg erklärt zwischen %s und %s" % [nation_a, nation_b])
	war_declared.emit(nation_a, nation_b)

func make_peace(nation_a: String, nation_b: String):
	if wars.has(nation_a):
		wars[nation_a].erase(nation_b)
	if wars.has(nation_b):
		wars[nation_b].erase(nation_a)

	print("Frieden geschlossen zwischen %s und %s" % [nation_a, nation_b])
	peace_made.emit(nation_a, nation_b)
