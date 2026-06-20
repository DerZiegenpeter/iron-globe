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

	# === STATS ===
	var stats_text := ""
	stats_text += "[b]Readiness:[/b] %.1f%%\n" % (entity.equipment_readiness * 100)
	stats_text += "[b]Manpower:[/b] %d / %d\n" % [entity.manpower, entity.max_manpower]
	stats_text += "[b]Organization:[/b] %.1f / %.1f\n" % [entity.organization, entity.max_organization]
	stats_text += "[b]Experience:[/b] %.1f\n\n" % entity.experience
	stats_text += "[b]Soft Attack:[/b] %.1f\n" % entity.soft_attack
	stats_text += "[b]Hard Attack:[/b] %.1f\n" % entity.hard_attack
	stats_text += "[b]Defense:[/b] %.1f\n" % entity.defense
	stats_text += "[b]Breakthrough:[/b] %.1f\n" % entity.breakthrough
	stats_text += "[b]Supply Consumption:[/b] %.2f\n" % entity.supply_consumption

	stats_label.text = stats_text

	# === EQUIPMENT ===
	var equip_text := "[b]AUSRÜSTUNG[/b]\n\n"

	if entity.required_equipment.is_empty():
		equip_text += "Keine Ausrüstungsanforderungen."
	else:
		for equip_id in entity.required_equipment:
			var needed = entity.required_equipment[equip_id]
			var missing = entity.missing_equipment.get(equip_id, 0)
			var fulfilled = needed - missing

			equip_text += "%s\n" % equip_id.capitalize()
			equip_text += "  Benötigt:   %d\n" % needed
			equip_text += "  Erfüllt:    %d\n" % fulfilled
			equip_text += "  Fehlend:    %d\n\n" % missing

	equipment_label.text = equip_text


func close_window():
	hide()
	current_entity = null
