extends Control
class_name UnitDetailsWindow

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var stats_label: RichTextLabel = $VBoxContainer/StatsLabel
@onready var equipment_label: RichTextLabel = $VBoxContainer/EquipmentLabel
@onready var close_button: Button = $VBoxContainer/CloseButton

var current_entity: GroundEntity = null


func _ready():
	close_button.pressed.connect(close_window)
	hide()


func open_for_entity(entity: GroundEntity):
	if not entity:
		return

	current_entity = entity
	show()

	title_label.text = "%s (%s)" % [entity.entity_name, entity.entity_type.capitalize()]

	# === STATS (kompakt) ===
	var stats_text := ""
	stats_text += "[b]Readiness:[/b] %.1f%%   |   [b]Manpower:[/b] %d/%d   |   [b]Org:[/b] %.1f/%.1f\n" % [
		entity.equipment_readiness * 100, entity.manpower, entity.max_manpower,
		entity.organization, entity.max_organization
	]
	stats_text += "[b]Experience:[/b] %.1f   |   [b]Soft:[/b] %.1f   [b]Hard:[/b] %.1f   [b]Def:[/b] %.1f   [b]Break:[/b] %.1f\n" % [
		entity.experience, entity.soft_attack, entity.hard_attack, entity.defense, entity.breakthrough
	]
	stats_text += "[b]Supply Consumption:[/b] %.2f\n" % entity.supply_consumption

	stats_label.text = stats_text

	# === EQUIPMENT (soll/ist) - bleibt kompakt ===
	var equip_text := "[b]AUSRÜSTUNG (soll / ist)[/b]\n"

	if entity.required_equipment.is_empty():
		equip_text += "Keine Ausrüstungsanforderungen.\n"
	else:
		for equip_id in entity.required_equipment:
			var needed = entity.required_equipment[equip_id]
			var missing = entity.missing_equipment.get(equip_id, 0)
			var fulfilled = needed - missing
			equip_text += "%s:  %d / %d  (fehlt %d)\n" % [equip_id.capitalize(), fulfilled, needed, missing]

	equipment_label.text = equip_text

	# Hinweis: Für die volle Komposition (Bataillone) siehe unten oder erweitere das Fenster.
	# Wenn du die Komposition hier sehen willst, drücke auf einen Button oder erweitere das UI-Fenster.


func close_window():
	hide()
	current_entity = null
