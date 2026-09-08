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
	return maxf(float(safe.position.y), 0.0) * scale_for(viewport)


static func bottom_inset(viewport: Viewport) -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	return maxf(float(win.y - safe.end.y), 0.0) * scale_for(viewport)
