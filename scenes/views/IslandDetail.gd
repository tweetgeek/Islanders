extends Node2D

## Dom gracza: osada aktywna z plakietkami slotów. Cudze i niczyje wyspy obsługuje InspectSheet
## nad mapą, nie ten widok. Tap w slot otwiera BuildingSheet przez grupę "sheets".

const DETAIL_RADIUS := 400.0
## Przycisk docku (rozmiar) plus prześwit nad nim (odstęp), żeby wyspa nie chowała się pod dokiem.
const DOCK_TOOL := 46.0
const DOCK_GAP := 24.0
const HINT_MARGIN := 10.0
const HINT_TEXT := "Dotknij slotu, żeby otworzyć budynek"
const NO_SETTLEMENT_TEXT := "Brak osady"

@onready var generator: IslandGenerator = $Generator
@onready var camera: Camera2D = $Camera
@onready var hint_panel: PanelContainer = $UI/HintPanel
@onready var hint_label: Label = $UI/HintPanel/Hint

var _settlement: Settlement = null
var _pressed_slot: int = -1
## Indeks dotyku, który trzyma wciśnięty slot. Widok osady obsługuje wyłącznie tapnięcie,
## więc drugi palec jest ignorowany, dopóki pierwszy nie puści - inaczej nadpisałby _pressed_slot
## i zostawił poprzednią plakietkę wciśniętą na zawsze (MapCamera rozwiązuje to tak samo).
var _pressed_index: int = -1
var _hint_dismissed := false


func _ready() -> void:
	GameState.active_settlement_changed.connect(_refresh)
	GameState.settlement_updated.connect(_on_settlement_updated)
	get_viewport().size_changed.connect(_layout)
	var hud := _hud()
	if hud != null:
		hud.bar_height_changed.connect(_layout)
	_refresh()
	_layout()


func _refresh() -> void:
	_settlement = GameState.active_settlement
	_pressed_slot = -1
	_pressed_index = -1
	if _settlement == null:
		generator.clear()
		hint_label.text = NO_SETTLEMENT_TEXT
		hint_panel.show()
		return
	var island := GameState.island_at(_settlement.coord)
	generator.seed_val = island.seed_val if island != null else hash(_settlement.coord)
	generator.biome = _settlement.biome
	generator.radius = DETAIL_RADIUS
	generator.show_deposit = false
	generator.show_slots = true
	generator.settlement = _settlement
	generator.build()
	hint_label.text = HINT_TEXT
	hint_panel.visible = not _hint_dismissed


func _on_settlement_updated(coord: Vector2i) -> void:
	if _settlement != null and coord == _settlement.coord:
		_refresh()


## Wyspa w środku obszaru między dołem paska HUD a górą docku.
func _layout() -> void:
	var vis := get_viewport().get_visible_rect().size
	var top := _hud_bar_height()
	var bottom := vis.y - SafeArea.bottom_inset(get_viewport()) - MedievalTheme.px(DOCK_TOOL) - MedievalTheme.gap(DOCK_GAP)
	var mid := (top + bottom) / 2.0
	camera.position = Vector2(0.0, vis.y / 2.0 - mid)
	hint_panel.offset_left = MedievalTheme.gap(HINT_MARGIN)
	hint_panel.offset_bottom = -(vis.y - bottom)


func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud")


func _hud_bar_height() -> float:
	var hud := _hud()
	return hud.bar_height() if hud != null else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _settlement == null or not generator.show_slots:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# Gest już należy do innego palca: ignorujemy, żeby nie nadpisać _pressed_slot.
			if _pressed_index != -1:
				return
			var slot := _slot_under(event.position)
			_pressed_index = event.index
			_pressed_slot = slot
			if slot >= 0:
				generator.set_pressed(slot, true)
		else:
			if event.index != _pressed_index:
				return
			var slot := _slot_under(event.position)
			if _pressed_slot >= 0:
				generator.set_pressed(_pressed_slot, false)
			if slot >= 0 and slot == _pressed_slot:
				_open_building(slot)
			_pressed_slot = -1
			_pressed_index = -1
	elif event is InputEventScreenDrag and event.index == _pressed_index and _pressed_slot >= 0:
		if _slot_under(event.position) != _pressed_slot:
			generator.set_pressed(_pressed_slot, false)
			_pressed_slot = -1


func _slot_under(screen_pos: Vector2) -> int:
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	return generator.slot_at(generator.to_local(world_pos))


func _open_building(slot: int) -> void:
	var sheets := get_tree().get_first_node_in_group("sheets")
	if sheets == null:
		push_warning("IslandDetail: brak węzła w grupie sheets")
		return
	if sheets.open_building(_settlement, slot):
		_hint_dismissed = true
		hint_panel.hide()
