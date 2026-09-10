extends CanvasLayer

## Górny pasek osady aktywnej: wiersz tożsamości i pięć kart zasobów. Nie liczy nic sam:
## woła Settlement.current_resources(TimeUtil.now()). Pokazuje wyłącznie osadę aktywną;
## oglądana wyspa to zadanie InspectSheet, a populacja mieszka w widoku osady.

## Emitowany, gdy wysokość paska naprawdę się zmieniła - po ustaleniu layoutu, nie w trakcie.
## Widoki podpięte do samego size_changed czytają bar_height() jeszcze sprzed przepięcia
## ResourceGrid (przesortowanie kontenera jest odroczone), więc potrzebują tego sygnału.
signal bar_height_changed

const PAD := 12.0
const ICON := 24.0

@onready var top_bar: PanelContainer = $TopBar
@onready var pad: MarginContainer = $TopBar/Pad
@onready var bar_rows: VBoxContainer = $TopBar/Pad/BarRows
@onready var identity_row: HBoxContainer = $TopBar/Pad/BarRows/IdentityRow
@onready var settlement_name: Label = $TopBar/Pad/BarRows/IdentityRow/SettlementName
@onready var biome_badge: Label = $TopBar/Pad/BarRows/IdentityRow/BiomeBadge
@onready var subtitle: Label = $TopBar/Pad/BarRows/IdentityRow/Subtitle
@onready var resource_grid: HBoxContainer = $TopBar/Pad/BarRows/ResourceGrid

var _settlement: Settlement = null
## zasób -> PanelContainer (cała karta)
var cards: Dictionary = {}
var _icons: Dictionary = {}
var _amounts: Dictionary = {}
var _rates: Dictionary = {}
var _last_bar_height := -1.0


func _ready() -> void:
	_style_static_nodes()
	_build_cards()
	GameState.active_settlement_changed.connect(_on_active_changed)
	GameState.settlement_updated.connect(_on_settlement_updated)
	get_viewport().size_changed.connect(_on_size_changed)
	top_bar.resized.connect(_notify_bar_height)
	_on_size_changed()
	_on_active_changed()


func _style_static_nodes() -> void:
	var p := MedievalTheme.gap(PAD)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, p)
	bar_rows.add_theme_constant_override("separation", MedievalTheme.gap(9))
	identity_row.add_theme_constant_override("separation", MedievalTheme.gap(10))
	resource_grid.add_theme_constant_override("separation", MedievalTheme.gap(6))


func _build_cards() -> void:
	for r in ResourceTypes.ALL:
		var card := PanelContainer.new()
		card.name = r.capitalize() + "Card"
		card.theme_type_variation = &"ResCard"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", MedievalTheme.gap(2))
		var top := HBoxContainer.new()
		top.name = "TopRow"
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Icon.new()
		icon.name = "Icon"
		icon.kind = ResourceTypes.ICONS[r]
		icon.color = ResourceTypes.COLORS[r]
		icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
		var amount := Label.new()
		amount.name = "Amount"
		amount.theme_type_variation = &"Amount"
		amount.text = "0"
		var rate := Label.new()
		rate.name = "Rate"
		rate.theme_type_variation = &"Rate"
		top.add_child(icon)
		top.add_child(amount)
		box.add_child(top)
		box.add_child(rate)
		card.add_child(box)
		resource_grid.add_child(card)
		cards[r] = card
		_icons[r] = icon
		_amounts[r] = amount
		_rates[r] = rate


func icon_of(resource: String) -> Icon:
	return _icons[resource]


func amount_of(resource: String) -> Label:
	return _amounts[resource]


func rate_of(resource: String) -> Label:
	return _rates[resource]


## Dolna krawędź paska w pikselach canvasu; widoki układają pod nią swoje UI.
func bar_height() -> float:
	return top_bar.offset_top + top_bar.size.y


## Sygnał leci tylko przy realnej zmianie, więc wolno wołać to i z resized, i z size_changed:
## ta pierwsza wartość bywa jeszcze sprzed przesortowania, druga zawsze ją domyka.
func _notify_bar_height() -> void:
	var h := bar_height()
	if is_equal_approx(h, _last_bar_height):
		return
	_last_bar_height = h
	bar_height_changed.emit()


func _on_active_changed() -> void:
	_settlement = GameState.active_settlement
	if _settlement == null:
		settlement_name.text = "-"
		biome_badge.text = ""
		subtitle.text = ""
		for r in ResourceTypes.ALL:
			_amounts[r].text = "0"
			_rates[r].text = ""
			_apply_card_state(r, true)
		return
	settlement_name.text = _settlement.name
	biome_badge.text = Biome.key(_settlement.biome)
	var world_id := GameState.world.id if GameState.world != null else "?"
	subtitle.text = "Świat %s · (%d, %d)" % [world_id, _settlement.coord.x, _settlement.coord.y]
	for r in ResourceTypes.ALL:
		var produces := _settlement.produces(r)
		_rates[r].text = "+%d/h" % int(_settlement.production_per_hour[r]) if produces else ""
		_apply_card_state(r, produces)


## Stan „nie produkuję” niosą paleta i treść, nie przezroczystość: modulate mnożyłby alfę także
## liczby i ikony, a półprzezroczysty pergamin na dębie wychodził błotem.
func _apply_card_state(r: String, produces: bool) -> void:
	var face := MedievalTheme.PARCHMENT if produces else MedievalTheme.VELLUM
	var card: PanelContainer = cards[r]
	# Najpierw zdejmujemy własne nadpisanie, żeby duplikować styl z motywu, a nie poprzedni stan.
	card.remove_theme_stylebox_override("panel")
	var base := card.get_theme_stylebox("panel")
	if base is StyleBoxFlat:
		var sb: StyleBoxFlat = base.duplicate()
		sb.bg_color = face
		card.add_theme_stylebox_override("panel", sb)
	var icon: Icon = _icons[r]
	icon.color = ResourceTypes.COLORS[r] if produces else MedievalTheme.INK_SOFT
	icon.knockout = face
	_amounts[r].add_theme_color_override("font_color", MedievalTheme.INK if produces else MedievalTheme.INK_SOFT)


func _on_settlement_updated(coord: Vector2i) -> void:
	if _settlement != null and coord == _settlement.coord:
		_on_active_changed()


func _process(_delta: float) -> void:
	if _settlement == null:
		return
	var current := _settlement.current_resources(TimeUtil.now())
	for r in ResourceTypes.ALL:
		_amounts[r].text = TimeUtil.format_thousands(current[r])


func _on_size_changed() -> void:
	top_bar.offset_top = SafeArea.top_inset(get_viewport())
	_apply_orientation()
	_notify_bar_height()


## Portret: karty zasobów pod wierszem tożsamości. Landscape: karty w tym samym wierszu po prawej,
## żeby obszar gry zachował wysokość.
func _apply_orientation() -> void:
	var vis := get_viewport().get_visible_rect().size
	var landscape := vis.x > vis.y
	var parent := resource_grid.get_parent()
	if landscape and parent != identity_row:
		parent.remove_child(resource_grid)
		identity_row.add_child(resource_grid)
		resource_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif not landscape and parent != bar_rows:
		parent.remove_child(resource_grid)
		bar_rows.add_child(resource_grid)
		bar_rows.move_child(resource_grid, 1)
		resource_grid.size_flags_horizontal = Control.SIZE_FILL
