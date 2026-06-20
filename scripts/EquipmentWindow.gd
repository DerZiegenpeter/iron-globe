extends Control
class_name EquipmentWindow

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var content_label: RichTextLabel = $VBoxContainer/ContentLabel
@onready var close_button: Button = $VBoxContainer/CloseButton

var equip_manager: EquipmentManager
var current_nation: String = "GER"


func _ready():
	close_button.pressed.connect(close_window)
	equip_manager = get_node_or_null("/root/EquipmentManager")
	hide()


func open_for_category(category: String, nation: String = "GER"):
	if not equip_manager:
		return

	current_nation = nation
	show()
	title_label.text = "%s - %s" % [nation, category]

	var stock = equip_manager.get_stockpile(nation)
	var text := ""

	for equip_id in equip_manager.equipment_definitions:
		var cat = equip_manager.get_equipment_category(equip_id)
		if cat != category:
			continue

		var name = equip_manager.get_equipment_display_name(equip_id)
		var amount = stock.get(equip_id, 0)

		text += "[b]%s[/b]\n" % name
		text += "   Bestand: %d\n\n" % amount

	if text == "":
		text = "Keine Ausrüstung in dieser Kategorie vorhanden."

	content_label.text = text


func close_window():
	hide()
