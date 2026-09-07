extends CanvasLayer

## Pasek zasobów osady aktywnej. Nie liczy nic sam: woła Settlement.current_resources(TimeUtil.now()).

const BAR_HEIGHT := 96.0
const NARROW_WIDTH := 700.0
const ICON_SIZE := 24.0
const DIMMED := 0.45

@onready var top_bar: PanelContainer = $TopBar
@onready var chips: HBoxContainer = $TopBar/HBox/Chips
@onready var population_label: Label = $TopBar/HBox/Population
@onready var name_label: Label = $TopBar/HBox/SettlementName

var _settlement: Settlement = null
## zasób -> Label
var _labels: Dictionary = {}
## zasób -> HBoxContainer (cały chip)
var _chips: Dictionary = {}


func _ready() -> void:
	_build_chips()
	GameState.active_settlement_changed.connect(_on_active_changed)
	GameState.settlement_updated.connect(_on_settlement_updated)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_on_active_changed()


func _build_chips() -> void:
	for r in ResourceTypes.ALL:
		var chip := HBoxContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := ColorRect.new()
		icon.color = ResourceTypes.COLORS[r]
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(icon)
		var label := Label.new()
		label.text = "0"
		chip.add_child(label)
		chips.add_child(chip)
		_labels[r] = label
		_chips[r] = chip


func _on_active_changed() -> void:
	_settlement = GameState.active_settlement
	if _settlement == null:
		name_label.text = "-"
		return
	name_label.text = "%s (%d, %d)" % [_settlement.name, _settlement.coord.x, _settlement.coord.y]
	_dim_chips()


func _on_settlement_updated(coord: Vector2i) -> void:
	if _settlement != null and coord == _settlement.coord:
		_on_active_changed()


func _process(_delta: float) -> void:
	if _settlement == null:
		return
	var current := _settlement.current_resources(TimeUtil.now())
	var narrow := get_viewport().get_visible_rect().size.x < NARROW_WIDTH
	for r in ResourceTypes.ALL:
		_labels[r].text = TimeUtil.format_amount(current[r]) if narrow else "%d" % int(floorf(current[r]))
	population_label.text = "%d / %d" % [_settlement.population, _settlement.population_max]


func _dim_chips() -> void:
	for r in ResourceTypes.ALL:
		_chips[r].modulate.a = 1.0 if _settlement.produces(r) else DIMMED


## Przesuwa pasek pod notch; safe area jest w pikselach okna, viewport w pikselach canvasu.
func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var vis := get_viewport().get_visible_rect().size
	var scale := vis.y / maxf(float(win.y), 1.0)
	var top := float(safe.position.y) * scale
	top_bar.offset_top = top
	top_bar.offset_bottom = top + BAR_HEIGHT
