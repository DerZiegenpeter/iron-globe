extends Control
class_name TopBar

signal tab_selected(tab_name: String)

@onready var nation_label: Label = $HBoxContainer/NationContainer/NationLabel

# Tabs
@onready var btn_government: Button = $HBoxContainer/Tabs/GovernmentButton
@onready var btn_politics: Button   = $HBoxContainer/Tabs/PoliticsButton
@onready var btn_population: Button = $HBoxContainer/Tabs/PopulationButton
@onready var btn_diplomacy: Button  = $HBoxContainer/Tabs/DiplomacyButton
@onready var btn_industry: Button   = $HBoxContainer/Tabs/IndustryButton
@onready var btn_economy: Button    = $HBoxContainer/Tabs/EconomyButton
@onready var btn_military: Button   = $HBoxContainer/Tabs/MilitaryButton
@onready var btn_research: Button   = $HBoxContainer/Tabs/ResearchButton


func _ready():
	_connect_buttons()
	_update_nation_info()


func _connect_buttons():
	if btn_government: btn_government.pressed.connect(_on_tab_pressed.bind("Government"))
	if btn_politics:   btn_politics.pressed.connect(_on_tab_pressed.bind("Politics"))
	if btn_population: btn_population.pressed.connect(_on_tab_pressed.bind("Population"))
	if btn_diplomacy:  btn_diplomacy.pressed.connect(_on_tab_pressed.bind("Diplomacy"))
	if btn_industry:   btn_industry.pressed.connect(_on_tab_pressed.bind("Industry"))
	if btn_economy:    btn_economy.pressed.connect(_on_tab_pressed.bind("Economy"))
	if btn_military:   btn_military.pressed.connect(_on_tab_pressed.bind("Military"))
	if btn_research:   btn_research.pressed.connect(_on_tab_pressed.bind("Research"))


func _on_tab_pressed(tab_name: String):
	tab_selected.emit(tab_name)
	print("TopBar → Tab geöffnet: ", tab_name)


func _update_nation_info():
	if nation_label:
		nation_label.text = "Germany  •  1941"


func set_nation_info(nation_name: String, year: int = 0):
	if nation_label:
		nation_label.text = "%s  •  %d" % [nation_name, year] if year > 0 else nation_name
