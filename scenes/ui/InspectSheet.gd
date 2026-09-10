class_name InspectSheet
extends PanelContainer

## Arkusz oglądanej wyspy nad mapą: cudza osada (dane publiczne), wyspa niczyja (znalezisko)
## albo własna osada (dane publiczne i akcja wejścia). Dane prywatne własnej osady są o jedno
## tapnięcie dalej, w widoku osady - arkusz ich nie powiela.

signal close_requested
## Jedyna droga zmiany osady aktywnej z mapy (glosariusz: Active Settlement).
signal enter_settlement_requested(coord: Vector2i)

const ENTER_TEXT := "PRZEJDŹ DO OSADY"
const RETURN_TEXT := "WRÓĆ DO OSADY"
const ACTION_HEIGHT := 48.0

@onready var grabber: Panel = $SheetMargin/Body/Grabber
@onready var biome_icon: Icon = $SheetMargin/Body/Header/HBox/BiomeIcon
@onready var name_label: Label = $SheetMargin/Body/Header/HBox/Name
@onready var biome_badge: Label = $SheetMargin/Body/Header/HBox/BiomeBadge
@onready var close_button: Button = $SheetMargin/Body/Header/HBox/CloseButton
@onready var subtitle: Label = $SheetMargin/Body/Subtitle
@onready var public_label: Label = $SheetMargin/Body/PublicLabel
@onready var deposit_header: Label = $SheetMargin/Body/DepositHeader
@onready var deposit_row: HBoxContainer = $SheetMargin/Body/DepositRow
@onready var empty_label: Label = $SheetMargin/Body/EmptyLabel
@onready var action_button: Button = $SheetMargin/Body/ActionButton

var _coord: Vector2i = Coord.NONE


func _ready() -> void:
	SheetStyle.apply_common(self, grabber, biome_icon, close_button, close_requested, 40.0)
	subtitle.add_theme_color_override("font_color", MedievalTheme.INK_SOFT)
	action_button.custom_minimum_size.y = MedievalTheme.px(ACTION_HEIGHT)
	action_button.pressed.connect(func() -> void: enter_settlement_requested.emit(_coord))


## Zwraca false (i push_error) dla komórki bez wyspy.
func open(coord: Vector2i) -> bool:
	var island := GameState.island_at(coord)
	if island == null:
		push_error("InspectSheet: %s nie jest wyspą" % coord)
		return false
	var s := GameState.settlement_at(coord)
	biome_icon.kind = ResourceTypes.ICONS[Biome.resources(island.biome)[0]]
	biome_badge.text = Biome.key(island.biome)
	# remove_child przed queue_free: dwa open() w jednej klatce zostawiłyby stare chipy
	# podpięte pod DepositRow aż do końca klatki (tak samo robi FleetsSheet.refresh).
	for c in deposit_row.get_children():
		deposit_row.remove_child(c)
		c.queue_free()
	_coord = coord
	action_button.hide()
	if s != null and s.is_own:
		name_label.text = s.name
		subtitle.text = "(%d, %d) · twoja osada" % [coord.x, coord.y]
		public_label.hide()
		deposit_header.hide()
		deposit_row.hide()
		empty_label.hide()
		var active := GameState.active_settlement
		action_button.text = RETURN_TEXT if active != null and active.coord == coord else ENTER_TEXT
		action_button.show()
		return true
	if s != null:
		name_label.text = s.name
		subtitle.text = "(%d, %d) · %s" % [coord.x, coord.y, s.owner_name]
		public_label.show()
		deposit_header.hide()
		deposit_row.hide()
		empty_label.hide()
		return true
	name_label.text = "Wyspa (%d, %d)" % [coord.x, coord.y]
	subtitle.text = "(%d, %d) · wyspa niczyja" % [coord.x, coord.y]
	public_label.hide()
	if island.has_deposit():
		for r in island.deposit:
			deposit_row.add_child(_chip(r, float(island.deposit[r])))
		deposit_header.show()
		deposit_row.show()
		empty_label.hide()
	else:
		deposit_header.hide()
		deposit_row.hide()
		empty_label.show()
	return true


func _chip(resource: String, amount: float) -> PanelContainer:
	var chip := SheetStyle.resource_chip(resource)
	var label := SheetStyle.chip_amount(chip)
	label.add_theme_color_override("font_color", MedievalTheme.CREAM)
	label.text = "%s %s" % [TimeUtil.format_thousands(amount), ResourceTypes.LABELS[resource].to_lower()]
	return chip
