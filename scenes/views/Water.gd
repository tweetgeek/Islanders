extends Node2D

## Siatka komórek w widocznym prostokącie; WorldMap ustawia visible_rect co klatkę.

const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.06)

var visible_rect := Rect2()


func _draw() -> void:
	var cs := WorldGrid.CELL_SIZE
	var x0 := floorf(visible_rect.position.x / cs) * cs
	var y0 := floorf(visible_rect.position.y / cs) * cs
	var x := x0
	while x <= visible_rect.end.x:
		draw_line(Vector2(x, visible_rect.position.y), Vector2(x, visible_rect.end.y), LINE_COLOR, 1.0)
		x += cs
	var y := y0
	while y <= visible_rect.end.y:
		draw_line(Vector2(visible_rect.position.x, y), Vector2(visible_rect.end.x, y), LINE_COLOR, 1.0)
		y += cs
