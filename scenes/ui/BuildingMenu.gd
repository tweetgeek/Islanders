class_name BuildingMenu
extends PanelContainer

## Panel budynku: nazwa, poziom, "Ulepsz". Bez logiki; emituje upgrade_requested.

signal upgrade_requested(building: int)

@onready var title: Label = $VBox/Title
@onready var level_label: Label = $VBox/Level
@onready var upgrade_button: Button = $VBox/Upgrade
@onready var close_button: Button = $VBox/Close

var _building: int = -1


func _ready() -> void:
	hide()
	upgrade_button.pressed.connect(_on_upgrade)
	close_button.pressed.connect(hide)


func open(building: Buildings.Type, level: int) -> void:
	_building = building
	title.text = Buildings.label(building)
	level_label.text = "Poziom %d" % level
	upgrade_button.text = "Ulepsz do %d" % (level + 1)
	show()


func _on_upgrade() -> void:
	upgrade_requested.emit(_building)
