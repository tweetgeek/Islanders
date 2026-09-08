class_name FleetRenderer
extends Node2D

const OWN_COLOR := Color(1.0, 0.85, 0.2)
const INCOMING_COLOR := Color(0.95, 0.25, 0.2)
const DASH := 24.0
const TRIANGLE := 14.0
const FONT_SIZE := 16

var _fleets: Array = []


func _ready() -> void:
	refresh()


func refresh() -> void:
	_fleets = GameState.fleets.values()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var now := TimeUtil.now()
	var font := ThemeDB.fallback_font
	for f: Fleet in _fleets:
		if f.is_arrived(now):
			continue
		var a := WorldGrid.cell_to_world(f.from)
		var b := WorldGrid.cell_to_world(f.to)
		var color := OWN_COLOR if f.is_own(GameState.player_id) else INCOMING_COLOR
		draw_dashed_line(a, b, color, 2.0, DASH)
		var pos := f.position_at(now)
		var dir := f.direction()
		var tri := PackedVector2Array([
			pos + dir * TRIANGLE,
			pos + dir.rotated(2.5) * TRIANGLE * 0.7,
			pos + dir.rotated(-2.5) * TRIANGLE * 0.7,
		])
		draw_colored_polygon(tri, color)
		var text := "%s %s" % [f.mission.left(3), TimeUtil.format_countdown(f.remaining_seconds(now))]
		draw_string(font, pos + Vector2(-32, -TRIANGLE - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
