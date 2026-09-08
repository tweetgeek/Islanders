extends CanvasLayer

## Górny pasek osady aktywnej. Nie liczy nic sam: woła Settlement.current_resources(TimeUtil.now()).
## Pokazuje wyłącznie osadę aktywną; oglądana wyspa to zadanie InspectSheet.

const NARROW_WIDTH := 700.0
## 45% nieprzezroczystości. Color.modulate.a to float32 (silnik, nie GDScript), więc dosłowne
## 0.45 (float64) zaokrągla się przy zapisie do Color; ta stała to dokładnie ten sam bit float32
## podniesiony z powrotem do float64 - odczyt modulate.a po zapisie znów równa się DIMMED.
const DIMMED := 0.44999998807907104
const PAD := 12.0
const AVATAR := 40.0
const ICON := 24.0
const SMALL_ICON := 16.0
const POP_WARN := 0.95

@onready var top_bar: PanelContainer = $TopBar
@onready var pad: MarginContainer = $TopBar/Pad
@onready var bar_rows: VBoxContainer = $TopBar/Pad/BarRows
@onready var profile_row: HBoxContainer = $TopBar/Pad/BarRows/ProfileRow
@onready var avatar: Icon = $TopBar/Pad/BarRows/ProfileRow/Avatar
@onready var settlement_name: Label = $TopBar/Pad/BarRows/ProfileRow/Identity/NameRow/SettlementName
@onready var biome_badge: Label = $TopBar/Pad/BarRows/ProfileRow/Identity/NameRow/BiomeBadge
@onready var subtitle: Label = $TopBar/Pad/BarRows/ProfileRow/Identity/Subtitle
@onready var gold_icon: Icon = $TopBar/Pad/BarRows/ProfileRow/GoldPanel/HBox/GoldIcon
@onready var gold_label: Label = $TopBar/Pad/BarRows/ProfileRow/GoldPanel/HBox/GoldLabel
@onready var resource_grid: HBoxContainer = $TopBar/Pad/BarRows/ResourceGrid
@onready var pop_icon: Icon = $TopBar/Pad/BarRows/PopulationRow/PopIcon
@onready var pop_bar: ProgressBar = $TopBar/Pad/BarRows/PopulationRow/PopBar
@onready var pop_label: Label = $TopBar/Pad/BarRows/PopulationRow/PopLabel

var _settlement: Settlement = null
## zasób -> PanelContainer (cała karta)
var cards: Dictionary = {}
var _icons: Dictionary = {}
var _amounts: Dictionary = {}
var _rates: Dictionary = {}


func _ready() -> void:
	_style_static_nodes()
	_build_cards()
	GameState.active_settlement_changed.connect(_on_active_changed)
	GameState.settlement_updated.connect(_on_settlement_updated)
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed()
	_on_active_changed()


func _style_static_nodes() -> void:
	var p := MedievalTheme.px(PAD)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, p)
	bar_rows.add_theme_constant_override("separation", MedievalTheme.px(9))
	profile_row.add_theme_constant_override("separation", MedievalTheme.px(10))
	resource_grid.add_theme_constant_override("separation", MedievalTheme.px(6))
	avatar.custom_minimum_size = Vector2.ONE * MedievalTheme.px(AVATAR)
	avatar.color = MedievalTheme.CREAM
	gold_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(SMALL_ICON)
	gold_icon.color = MedievalTheme.BRASS
	gold_label.add_theme_color_override("font_color", MedievalTheme.CREAM)   # placeholder pod przyszłą walutę
	pop_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(SMALL_ICON)
	pop_icon.color = MedievalTheme.CREAM_SOFT
	pop_bar.custom_minimum_size.y = MedievalTheme.px(8)
	pop_label.add_theme_color_override("font_color", MedievalTheme.CREAM)


func _build_cards() -> void:
	for r in ResourceTypes.ALL:
		var card := PanelContainer.new()
		card.name = r.capitalize() + "Card"
		card.theme_type_variation = &"ResCard"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", MedievalTheme.px(2))
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


func _on_active_changed() -> void:
	_settlement = GameState.active_settlement
	if _settlement == null:
		settlement_name.text = "-"
		biome_badge.text = ""
		subtitle.text = ""
		pop_label.text = "0 / 0"
		pop_bar.value = 0.0
		for r in ResourceTypes.ALL:
			_amounts[r].text = "0"
			_rates[r].text = ""
			cards[r].modulate.a = 1.0
		return
	settlement_name.text = _settlement.name
	biome_badge.text = Biome.key(_settlement.biome)
	var world_id := GameState.world.id if GameState.world != null else "?"
	subtitle.text = "Świat %s · (%d, %d)" % [world_id, _settlement.coord.x, _settlement.coord.y]
	for r in ResourceTypes.ALL:
		var produces := _settlement.produces(r)
		_rates[r].text = "+%d/h" % int(_settlement.production_per_hour[r]) if produces else ""
		cards[r].modulate.a = 1.0 if produces else DIMMED
	pop_bar.max_value = maxi(_settlement.population_max, 1)
	pop_bar.value = _settlement.population
	pop_label.text = "%d / %d" % [_settlement.population, _settlement.population_max]
	var warn := _settlement.population >= float(_settlement.population_max) * POP_WARN
	pop_label.add_theme_color_override("font_color", MedievalTheme.BLOOD if warn else MedievalTheme.CREAM)


func _on_settlement_updated(coord: Vector2i) -> void:
	if _settlement != null and coord == _settlement.coord:
		_on_active_changed()


func _process(_delta: float) -> void:
	if _settlement == null:
		return
	var current := _settlement.current_resources(TimeUtil.now())
	var narrow := get_viewport().get_visible_rect().size.x < NARROW_WIDTH
	for r in ResourceTypes.ALL:
		_amounts[r].text = TimeUtil.format_amount(current[r]) if narrow else TimeUtil.format_thousands(current[r])


func _on_size_changed() -> void:
	top_bar.offset_top = SafeArea.top_inset(get_viewport())
	_apply_orientation()


## Portret: karty zasobów pod wierszem profilu. Landscape: karty w tym samym wierszu po prawej,
## żeby obszar gry zachował wysokość.
func _apply_orientation() -> void:
	var vis := get_viewport().get_visible_rect().size
	var landscape := vis.x > vis.y
	var parent := resource_grid.get_parent()
	if landscape and parent != profile_row:
		parent.remove_child(resource_grid)
		profile_row.add_child(resource_grid)
		resource_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif not landscape and parent != bar_rows:
		parent.remove_child(resource_grid)
		bar_rows.add_child(resource_grid)
		bar_rows.move_child(resource_grid, 1)
		resource_grid.size_flags_horizontal = Control.SIZE_FILL
