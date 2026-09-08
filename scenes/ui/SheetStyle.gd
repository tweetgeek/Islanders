class_name SheetStyle
extends RefCounted

## Wspólne ustawienia arkuszy od dołu: margines, uchwyt, separacja.

const MARGIN := 14.0
const GRABBER := Vector2(44.0, 4.0)


static func apply_common(sheet: PanelContainer, grabber: Panel) -> void:
	var margin: MarginContainer = sheet.get_node("SheetMargin")
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MedievalTheme.px(MARGIN))
	(margin.get_child(0) as Control).add_theme_constant_override("separation", MedievalTheme.px(11))
	grabber.custom_minimum_size = Vector2(MedievalTheme.px(GRABBER.x), MedievalTheme.px(GRABBER.y))
	grabber.add_theme_stylebox_override("panel", MedievalTheme.flat(MedievalTheme.OAK_EDGE, MedievalTheme.OAK_EDGE, 2, 0, 0, 0))
