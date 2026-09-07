class_name MapCamera
extends Camera2D

## Pan jednym palcem (lub LPM przez emulację), pinch dwoma, scroll myszy, tap z progiem czasu i dystansu.

signal tapped(world_pos: Vector2)

const ZOOM_MIN := 0.25
const ZOOM_MAX := 2.0
const TAP_MAX_TIME := 0.25
const TAP_MAX_DIST := 12.0
const INERTIA_DAMP := 6.0
const SCROLL_STEP := 1.1

## index dotyku -> pozycja ekranowa
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _velocity := Vector2.ZERO
var _press_time := 0.0
var _drag_dist := 0.0
var _bounds := Rect2()
var _has_bounds := false


func set_bounds(rect: Rect2) -> void:
	_bounds = rect
	_has_bounds = true
	_clamp_position()


func visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	return Rect2(position - size / 2.0, size)


func screen_to_world(screen_pos: Vector2) -> Vector2:
	return position + (screen_pos - get_viewport_rect().size / 2.0) / zoom


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, SCROLL_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / SCROLL_STEP)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_press_time = Time.get_ticks_msec() / 1000.0
			_drag_dist = 0.0
			_velocity = Vector2.ZERO
		elif _touches.size() == 2:
			var pts: Array = _touches.values()
			_pinch_dist = pts[0].distance_to(pts[1])
			_velocity = Vector2.ZERO
	else:
		var was_single := _touches.size() == 1
		_touches.erase(e.index)
		_pinch_dist = 0.0
		if was_single:
			var elapsed := Time.get_ticks_msec() / 1000.0 - _press_time
			if elapsed < TAP_MAX_TIME and _drag_dist < TAP_MAX_DIST:
				tapped.emit(screen_to_world(e.position))


func _on_drag(e: InputEventScreenDrag) -> void:
	_touches[e.index] = e.position
	_drag_dist += e.relative.length()
	if _touches.size() == 1:
		position -= e.relative / zoom
		var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
		_velocity = -e.relative / zoom / dt
	elif _touches.size() == 2:
		var pts: Array = _touches.values()
		var d: float = pts[0].distance_to(pts[1])
		if _pinch_dist > 0.0:
			_zoom_at((pts[0] + pts[1]) / 2.0, d / _pinch_dist)
		_pinch_dist = d
	_clamp_position()


func _process(delta: float) -> void:
	if _touches.is_empty() and _velocity.length() > 1.0:
		position += _velocity * delta
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(INERTIA_DAMP * delta, 0.0, 1.0))
		_clamp_position()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_pos)
	var z := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	position += before - screen_to_world(screen_pos)
	_clamp_position()


func _clamp_position() -> void:
	if not _has_bounds:
		return
	var half := get_viewport_rect().size / zoom / 2.0
	if _bounds.size.x <= half.x * 2.0:
		position.x = _bounds.get_center().x
	else:
		position.x = clampf(position.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	if _bounds.size.y <= half.y * 2.0:
		position.y = _bounds.get_center().y
	else:
		position.y = clampf(position.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
