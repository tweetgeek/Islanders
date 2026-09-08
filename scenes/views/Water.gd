extends Node2D

## Siatka komórek w widocznym prostokącie; WorldMap ustawia visible_rect co klatkę.

## Siatka idzie za kolorem morza: SEA przyciemnione o 18% daje dokładnie to samo, co dawał
## czarny obrys w 18% krycia położony na SEA, ale przestrojenie morza pociągnie ją za sobą.
## (const nie liczy wywołań metod, stąd static var.)
static var LINE_COLOR := MedievalTheme.SEA.darkened(0.18)

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
