class_name SafeArea
extends RefCounted

## Safe area jest w pikselach okna, a kontrolki w pikselach canvasu (stretch canvas_items),
## więc offsety trzeba przeskalować. Jedno miejsce dla HUD, docku i widoków.


static func scale_for(viewport: Viewport) -> float:
	var win := DisplayServer.window_get_size()
	var vis := viewport.get_visible_rect().size
	return vis.y / maxf(float(win.y), 1.0)


static func top_inset(viewport: Viewport) -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var vis := viewport.get_visible_rect().size
	return insets_for(safe, win, vis).x


static func bottom_inset(viewport: Viewport) -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var vis := viewport.get_visible_rect().size
	return insets_for(safe, win, vis).y


## Czysta arytmetyka wstawek, żeby dało się ją przetestować z udawanym notchem:
## pod headless bezpieczny obszar równa się całemu oknu i obie wstawki wychodzą zerowe.
## Zwraca (górna, dolna) w pikselach canvasu.
static func insets_for(safe: Rect2i, window_size: Vector2i, viewport_size: Vector2) -> Vector2:
	var scale := viewport_size.y / maxf(float(window_size.y), 1.0)
	var top := maxf(float(safe.position.y), 0.0) * scale
	var bottom := maxf(float(window_size.y - safe.end.y), 0.0) * scale
	return Vector2(top, bottom)
