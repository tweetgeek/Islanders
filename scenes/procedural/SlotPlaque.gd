class_name SlotPlaque
extends Node2D

## Slot budynku jako rzeźbiona plakietka: pergaminowa twarz, dębowa krawędź, twardy cień.
## Rozmiar stały w pikselach świata; kamera osady nie zoomuje, więc na ekranie wygląda jak w mocku.
## Poziom 0: półprzezroczysta twarz z przerywaną krawędzią i ikoną plus.

const WIDTH := 160.0
const HEIGHT := 155.0
const RADIUS := 14
const BORDER := 6
const SHADOW := 8.0
const PRESS_TRAVEL := 8.0
const ICON_SIZE := 56.0
const DASH := 12.0
const EMPTY_ALPHA := 0.35

var building: int = -1
var level: int = 0
var pressed: bool = false:
	set(v):
		if pressed == v:
			return
		pressed = v
		_place_children()
		queue_redraw()

var _face: StyleBoxFlat
var _shadow: StyleBoxFlat
var _icon: Icon
var _label: Label


func _init() -> void:
	_face = StyleBoxFlat.new()
	_face.bg_color = MedievalTheme.PARCHMENT
	_face.set_corner_radius_all(RADIUS)
	_face.border_color = MedievalTheme.OAK
	_face.set_border_width_all(BORDER)
	_face.anti_aliasing = true
	_shadow = StyleBoxFlat.new()
	_shadow.bg_color = MedievalTheme.OAK_DEEP
	_shadow.set_corner_radius_all(RADIUS)
	_shadow.anti_aliasing = true
	_icon = Icon.new()
	_icon.name = "Icon"
	_icon.size = Vector2.ONE * ICON_SIZE
	add_child(_icon)
	_label = Label.new()
	_label.name = "Level"
	_label.theme_type_variation = &"Badge"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func setup(t: int, lvl: int) -> void:
	building = t
	level = lvl
	if level > 0:
		_icon.kind = Buildings.icon(t)
		_icon.color = MedievalTheme.INK
		_label.text = "LV %d" % level
		_label.visible = true
	else:
		_icon.kind = &"plus"
		_icon.color = MedievalTheme.OAK_DEEP
		_label.visible = false
	_label.reset_size()
	_place_children()
	queue_redraw()


## Jedno źródło przesunięcia wciśnięcia: używają go i _draw(), i _place_children(),
## więc twarz plakietki nigdy nie rozjedzie się z ikoną ani z odznaką.
func press_offset() -> Vector2:
	return Vector2(0.0, PRESS_TRAVEL) if pressed else Vector2.ZERO


func _place_children() -> void:
	var dy := press_offset().y
	if level > 0:
		_icon.position = Vector2(-ICON_SIZE / 2.0, -HEIGHT / 2.0 + 22.0 + dy)
		_label.position = Vector2(-_label.size.x / 2.0, HEIGHT / 2.0 - _label.size.y - 18.0 + dy)
	else:
		_icon.position = Vector2(-ICON_SIZE / 2.0, -ICON_SIZE / 2.0 + dy)


## Trafienie liczone samą twarzą plakietki, bez cienia.
func contains(local: Vector2) -> bool:
	return Rect2(-WIDTH / 2.0, -HEIGHT / 2.0, WIDTH, HEIGHT).has_point(local)


func _draw() -> void:
	var rect := Rect2(-WIDTH / 2.0, -HEIGHT / 2.0, WIDTH, HEIGHT)
	if level > 0:
		if not pressed:
			_shadow.draw(get_canvas_item(), Rect2(rect.position + Vector2(0, SHADOW), rect.size))
		_face.draw(get_canvas_item(), Rect2(rect.position + press_offset(), rect.size))
		return
	var empty_rect := Rect2(rect.position + press_offset(), rect.size)
	draw_rect(empty_rect, Color(MedievalTheme.PARCHMENT, EMPTY_ALPHA))
	var c := MedievalTheme.OAK_EDGE
	draw_dashed_line(empty_rect.position, Vector2(empty_rect.end.x, empty_rect.position.y), c, 3.0, DASH, true)
	draw_dashed_line(Vector2(empty_rect.end.x, empty_rect.position.y), empty_rect.end, c, 3.0, DASH, true)
	draw_dashed_line(empty_rect.end, Vector2(empty_rect.position.x, empty_rect.end.y), c, 3.0, DASH, true)
	draw_dashed_line(Vector2(empty_rect.position.x, empty_rect.end.y), empty_rect.position, c, 3.0, DASH, true)
