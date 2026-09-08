class_name BuildingSheet
extends PanelContainer

## Arkusz budynku: nazwa, poziom, opis, ZAMKNIJ / ULEPSZ. Bez logiki ulepszania.
## Sekcje kosztu i licznika istnieją, ale są ukryte, dopóki API ich nie zasili
## (refresh_costs / refresh_timer są publiczne właśnie na ten moment).

signal upgrade_requested(coord: Vector2i, building: int)
signal close_requested

const ICON := 46.0   # większa niż w InspectSheet: nagłówek arkusza budynku jest wyższy

@onready var grabber: Panel = $SheetMargin/ModalBody/Grabber
@onready var building_icon: Icon = $SheetMargin/ModalBody/Header/HBox/BuildingIcon
@onready var name_label: Label = $SheetMargin/ModalBody/Header/HBox/TitleBox/NameRow/Name
@onready var level_badge: Label = $SheetMargin/ModalBody/Header/HBox/TitleBox/NameRow/LevelBadge
@onready var subtitle: Label = $SheetMargin/ModalBody/Header/HBox/TitleBox/Subtitle
@onready var close_button: Button = $SheetMargin/ModalBody/Header/HBox/CloseButton
@onready var description: Label = $SheetMargin/ModalBody/Description
@onready var cost_section: VBoxContainer = $SheetMargin/ModalBody/CostSection
@onready var cost_header: Label = $SheetMargin/ModalBody/CostSection/CostHeader
@onready var cost_grid: GridContainer = $SheetMargin/ModalBody/CostSection/CostGrid
@onready var timer_section: VBoxContainer = $SheetMargin/ModalBody/TimerSection
@onready var timer_label: Label = $SheetMargin/ModalBody/TimerSection/TimerRow/TimerLabel
@onready var construction_bar: ProgressBar = $SheetMargin/ModalBody/TimerSection/ConstructionBar
@onready var cancel_button: Button = $SheetMargin/ModalBody/ActionRow/CancelButton
@onready var upgrade_button: Button = $SheetMargin/ModalBody/ActionRow/UpgradeButton

## zasób -> PanelContainer (chip kosztu)
var cost_chips: Dictionary = {}
var _cost_labels: Dictionary = {}
var _settlement: Settlement = null
var _building: int = -1
var _remaining := 0.0
var _total := 0.0


func _ready() -> void:
	SheetStyle.apply_common(self, grabber)
	building_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
	building_icon.color = MedievalTheme.CREAM
	close_button.custom_minimum_size = Vector2.ONE * MedievalTheme.px(SheetStyle.CLOSE)
	Icon.into_button(close_button, &"close", MedievalTheme.CREAM, MedievalTheme.px(7))
	for b in [cancel_button, upgrade_button]:
		b.custom_minimum_size.y = MedievalTheme.px(48)
	cost_grid.add_theme_constant_override("h_separation", MedievalTheme.px(6))
	_build_cost_chips()
	close_button.pressed.connect(func() -> void: close_requested.emit())
	cancel_button.pressed.connect(func() -> void: close_requested.emit())
	upgrade_button.pressed.connect(_on_upgrade)
	set_process(false)


func _build_cost_chips() -> void:
	for r in ResourceTypes.ALL:
		var chip := SheetStyle.resource_chip(r)
		chip.name = r.capitalize() + "Cost"
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cost_grid.add_child(chip)
		cost_chips[r] = chip
		_cost_labels[r] = SheetStyle.chip_amount(chip)


## Zwraca false (i push_error) dla budynku spoza slotów biomu osady.
func open(settlement: Settlement, building: int) -> bool:
	var slots := Biome.slots(settlement.biome)
	if not slots.has(building):
		push_error("BuildingSheet: budynek %s poza slotami biomu %s" % [Buildings.key(building), Biome.key(settlement.biome)])
		return false
	_settlement = settlement
	_building = building
	var level := settlement.level(building)
	building_icon.kind = Buildings.icon(building)
	name_label.text = Buildings.label(building)
	level_badge.text = "LV %d" % level
	subtitle.text = "%s · slot %d z %d" % [settlement.name, slots.find(building) + 1, slots.size()]
	description.text = Buildings.DESCRIPTIONS[building]
	upgrade_button.text = "BUDUJ" if level == 0 else "ULEPSZ"
	upgrade_button.disabled = false
	cost_section.hide()
	timer_section.hide()
	set_process(false)
	return true


## Pokazuje sekcję kosztu; chip zasobu widoczny, gdy koszt > 0; brakujący zasób na czerwono.
func refresh_costs(costs: Dictionary, stock: Dictionary) -> void:
	cost_header.text = "KOSZT ULEPSZENIA DO %d" % (_settlement.level(_building) + 1 if _settlement != null else 1)
	for r in ResourceTypes.ALL:
		var required := float(costs.get(r, 0.0))
		var held := float(stock.get(r, 0.0))
		var chip: PanelContainer = cost_chips[r]
		chip.visible = required > 0.0
		_cost_labels[r].text = TimeUtil.format_thousands(required)
		var short := held < required
		var sb := MedievalTheme.flat(
			MedievalTheme.SHORT_BG if short else MedievalTheme.VELLUM,
			MedievalTheme.BLOOD if short else MedievalTheme.OAK_EDGE, 3, 1, 8, 8)
		chip.add_theme_stylebox_override("panel", sb)
		_cost_labels[r].add_theme_color_override("font_color", MedievalTheme.BLOOD if short else MedievalTheme.INK)
	cost_section.show()


## Pokazuje sekcję licznika i odlicza w _process; ULEPSZ wyłączone, dopóki trwa budowa.
func refresh_timer(remaining: float, total: float) -> void:
	_remaining = maxf(remaining, 0.0)
	_total = maxf(total, 0.001)
	timer_section.show()
	_apply_timer()
	set_process(_remaining > 0.0)


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	_apply_timer()
	if is_zero_approx(_remaining):
		set_process(false)


func _apply_timer() -> void:
	var s := int(_remaining)
	@warning_ignore("integer_division")
	timer_label.text = "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	construction_bar.value = 1.0 - _remaining / _total
	upgrade_button.disabled = _remaining > 0.0


func _on_upgrade() -> void:
	if _settlement != null and _building >= 0:
		upgrade_requested.emit(_settlement.coord, _building)
	close_requested.emit()
