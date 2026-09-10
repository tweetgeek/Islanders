extends CanvasLayer

## Dock: „Floty” (z odznaką liczby flot w drodze) zawsze, „Mapa” tylko w widoku osady.
## Cudza flota w drodze barwi odznakę na BLOOD, żeby zagrożenie było widoczne z osady.

const TOOL := 46.0
const MARGIN := 10.0
const TICK := 1.0

@onready var fleets_button: Button = $Root/FleetsButton
@onready var badge: Label = $Root/FleetsButton/Badge
@onready var map_button: Button = $Root/MapButton

var _accum := 0.0
var _alarmed := false


func _ready() -> void:
	var tool := MedievalTheme.px(TOOL)
	for b in [fleets_button, map_button]:
		b.custom_minimum_size = Vector2(tool, tool)
		b.size = Vector2(tool, tool)
	Icon.into_button(fleets_button, &"fleet", MedievalTheme.CREAM, MedievalTheme.px(10))
	Icon.into_button(map_button, &"map", MedievalTheme.CREAM, MedievalTheme.px(10))
	badge.offset_left = -MedievalTheme.px(14)
	badge.offset_top = -MedievalTheme.px(8)
	fleets_button.pressed.connect(_on_fleets_pressed)
	map_button.pressed.connect(SceneManager.show_world_map)
	SceneManager.view_changed.connect(_sync_visibility)
	GameState.state_loaded.connect(func() -> void: _sync_visibility(SceneManager.current_view))
	GameState.fleets_updated.connect(refresh_badge)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_sync_visibility(SceneManager.current_view)
	refresh_badge()


func is_alarmed() -> bool:
	return _alarmed


func refresh_badge() -> void:
	var now := TimeUtil.now()
	var count := 0
	var alarmed := false
	for f: Fleet in GameState.fleets.values():
		if f.is_arrived(now):
			continue
		count += 1
		if not f.is_own(GameState.player_id):
			alarmed = true
	badge.visible = count > 0
	badge.text = str(count)
	_alarmed = alarmed
	if alarmed:
		badge.add_theme_stylebox_override("normal", MedievalTheme.flat(MedievalTheme.BLOOD, MedievalTheme.BLOOD, 2, 0, 5, 3))
		badge.add_theme_color_override("font_color", MedievalTheme.CREAM)
	else:
		badge.remove_theme_stylebox_override("normal")
		badge.remove_theme_color_override("font_color")


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= TICK:
		_accum = 0.0
		refresh_badge()


## Argument z sygnału view_changed, żeby dock nie zależał od kolejności aktualizacji current_view.
func _sync_visibility(path: String = "") -> void:
	if path.is_empty():
		path = SceneManager.current_view
	map_button.visible = path == SceneManager.VIEW_ISLAND_DETAIL and GameState.world != null


func _layout() -> void:
	var vis := get_viewport().get_visible_rect().size
	var m := MedievalTheme.gap(MARGIN)
	var tool := MedievalTheme.px(TOOL)
	var bottom := vis.y - SafeArea.bottom_inset(get_viewport()) - m - tool
	fleets_button.position = Vector2(m, bottom)
	map_button.position = Vector2(vis.x - m - tool, bottom)


func _on_fleets_pressed() -> void:
	var sheets := get_tree().get_first_node_in_group("sheets")
	if sheets != null:
		sheets.open_fleets()
