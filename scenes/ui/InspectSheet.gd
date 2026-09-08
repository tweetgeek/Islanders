class_name InspectSheet
extends PanelContainer

## Arkusz oglądanej wyspy nad mapą: cudza osada (dane publiczne) albo wyspa niczyja (znalezisko).

signal close_requested

const ICON := 40.0
const CLOSE := 30.0
const CHIP_ICON := 13.0

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


func _ready() -> void:
	SheetStyle.apply_common(self, grabber)
	biome_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
	biome_icon.color = MedievalTheme.CREAM
	close_button.custom_minimum_size = Vector2.ONE * MedievalTheme.px(CLOSE)
	Icon.into_button(close_button, &"close", MedievalTheme.CREAM, MedievalTheme.px(7))
	subtitle.add_theme_color_override("font_color", MedievalTheme.INK_SOFT)
	close_button.pressed.connect(func() -> void: close_requested.emit())


## Zwraca false (i push_error) dla komórki bez wyspy.
func open(coord: Vector2i) -> bool:
	var island := GameState.island_at(coord)
	if island == null:
		push_error("InspectSheet: %s nie jest wyspą" % coord)
		return false
	var s := GameState.settlement_at(coord)
	biome_icon.kind = ResourceTypes.ICONS[Biome.resources(island.biome)[0]]
	biome_badge.text = Biome.key(island.biome)
	for c in deposit_row.get_children():
		c.queue_free()
	if s != null:
		name_label.text = s.name
		subtitle.text = "(%d, %d) · gracz %d" % [coord.x, coord.y, s.owner_id]
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
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Icon.new()
	icon.kind = ResourceTypes.ICONS[resource]
	icon.color = ResourceTypes.COLORS[resource]
	icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(CHIP_ICON)
	var label := Label.new()
	label.theme_type_variation = &"Amount"
	label.add_theme_color_override("font_color", MedievalTheme.CREAM)
	label.text = "%s %s" % [TimeUtil.format_thousands(amount), ResourceTypes.LABELS[resource].to_lower()]
	box.add_child(icon)
	box.add_child(label)
	chip.add_child(box)
	return chip
