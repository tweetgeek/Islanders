class_name InspectSheet
extends PanelContainer

## Arkusz oglądanej wyspy nad mapą: cudza osada (dane publiczne) albo wyspa niczyja (znalezisko).

signal close_requested

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
	SheetStyle.apply_common(self, grabber, biome_icon, close_button, close_requested, 40.0)
	subtitle.add_theme_color_override("font_color", MedievalTheme.INK_SOFT)


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
	var chip := SheetStyle.resource_chip(resource)
	var label := SheetStyle.chip_amount(chip)
	label.add_theme_color_override("font_color", MedievalTheme.CREAM)
	label.text = "%s %s" % [TimeUtil.format_thousands(amount), ResourceTypes.LABELS[resource].to_lower()]
	return chip
