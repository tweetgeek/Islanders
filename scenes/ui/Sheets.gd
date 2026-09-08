extends CanvasLayer

## Zarządca arkuszy od dołu: backdrop, co najwyżej jeden otwarty arkusz, animacje otwarcia
## i zamknięcia, zamykanie przy zmianie widoku. Widoki wołają open_*(), reszta chrome nie.

signal upgrade_requested(coord: Vector2i, building: int)

const FADE_TIME := 0.18
const SLIDE_TIME := 0.26
const HEIGHT_FLEETS := 0.66
const HEIGHT_INSPECT := 0.34
const HEIGHT_BUILDING := 0.5

@onready var backdrop: ColorRect = $Backdrop
@onready var building_sheet: BuildingSheet = $BuildingSheet
@onready var inspect_sheet: InspectSheet = $InspectSheet
@onready var fleets_sheet: FleetsSheet = $FleetsSheet

var _current: Control = null
var _current_fraction := 0.0
var _tween: Tween = null


func _ready() -> void:
	visible = false
	backdrop.gui_input.connect(_on_backdrop_input)
	for s in _all_sheets():
		s.hide()
		s.close_requested.connect(close)
	building_sheet.upgrade_requested.connect(_on_upgrade_requested)
	fleets_sheet.fleet_tapped.connect(_on_fleet_tapped)
	SceneManager.view_changed.connect(func(_path: String) -> void: _hide_now())
	get_viewport().size_changed.connect(_relayout)


func _all_sheets() -> Array:
	var out: Array = []
	for c in get_children():
		if c != backdrop and c is PanelContainer:
			out.append(c)
	return out


func is_open() -> bool:
	return _current != null


func current_sheet() -> Control:
	return _current


func open_fleets() -> void:
	fleets_sheet.refresh()
	_open(fleets_sheet, HEIGHT_FLEETS)


func open_inspect(coord: Vector2i) -> bool:
	if not inspect_sheet.open(coord):
		return false
	_open(inspect_sheet, HEIGHT_INSPECT)
	return true


func open_building(settlement: Settlement, building: int) -> bool:
	if not building_sheet.open(settlement, building):
		return false
	_open(building_sheet, HEIGHT_BUILDING)
	return true


func close() -> void:
	if _current == null:
		return
	var panel := _current
	_current = null
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(backdrop, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_property(panel, "position:y", panel.position.y + panel.size.y, SLIDE_TIME)
	_tween.chain().tween_callback(func() -> void:
		panel.hide()
		if _current == null:
			visible = false
	)


## Otwiera panel: stan (_current, is_open()) jest widoczny od razu, ale sam layout+animacja
## czeka jedną klatkę na panel.show() (patrz _layout()) - to opóźnienie nie jest widoczne
## dla wywołujących, bo nie czekają na _open().
## Niezmiennik: żaden wywołujący nie otwiera tego samego panelu dwa razy w jednej klatce -
## drugie wywołanie zastałoby pierwsze wciąż przed swoim await i rozjechałoby animację.
func _open(panel: Control, fraction: float) -> void:
	_kill_tween()
	for s in _all_sheets():
		if s != panel:
			s.hide()
	_current = panel
	_current_fraction = fraction
	visible = true
	panel.show()
	backdrop.modulate.a = 0.0
	await get_tree().process_frame
	if panel != _current:
		return   # w międzyczasie zamknięty albo zastąpiony innym arkuszem
	_layout(panel, fraction)
	var rest := panel.position.y
	panel.position.y = rest + panel.size.y
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(backdrop, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_property(panel, "position:y", rest, SLIDE_TIME)


## Bez animacji: reakcja na zmianę widoku (SceneManager.view_changed). Otwarcie innego arkusza
## przy już otwartym obsługuje sam _open() (jego pętla chowa wszystko poza nowym arkuszem).
func _hide_now() -> void:
	_kill_tween()
	for s in _all_sheets():
		s.hide()
	_current = null
	visible = false
	backdrop.modulate.a = 1.0


## Arkusz zajmuje ułamek wysokości viewportu, przypięty do dołu na całą szerokość.
func _layout(panel: Control, fraction: float) -> void:
	var vis := get_viewport().get_visible_rect().size
	var h := roundf(vis.y * fraction)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = -h
	panel.offset_bottom = 0.0


func _relayout() -> void:
	if _current != null:
		_layout(_current, _current_fraction)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null


func _on_backdrop_input(event: InputEvent) -> void:
	var touch: bool = event is InputEventScreenTouch and event.pressed
	var click: bool = event is InputEventMouseButton and event.pressed
	if touch or click:
		close()


func _on_upgrade_requested(coord: Vector2i, building: int) -> void:
	upgrade_requested.emit(coord, building)


## Tap w kartę: arkusz znika, mapa otwiera się na pozycji floty (view_changed zamknie warstwę od razu).
func _on_fleet_tapped(fleet: Fleet) -> void:
	close()
	SceneManager.show_world_map_at(fleet.position_at(TimeUtil.now()))
