class_name MedievalTheme
extends RefCounted

## Motyw „Chart & Timber”: dębowy chrome, mosiężne linie, pergaminowe karty.
## Morze (tło Main) jest jedyną ciemną powierzchnią; UI leży na nim jak drewno i papier.
## Wymiary z projektu (viewport 390 px) przechodzą przez px(), bo nasz viewport ma 1080 px.

const SCALE := 2.77

const PARCHMENT := Color("eadfc4")
const VELLUM := Color("dccca6")
const CHART := Color("e3d3ac")
const RULE := Color("cbb484")
const OAK := Color("5a3e27")
const OAK_DEEP := Color("3d2917")
const OAK_EDGE := Color("8a6a3e")
const BRASS := Color("b8862b")
const BRASS_HOT := Color("dfae44")
const INK := Color("2a2015")
const INK_SOFT := Color("5c4b36")
const CREAM := Color("f3ead4")
const CREAM_SOFT := Color("d6c39d")
const SEA := Color("17383d")
const BLOOD := Color("8c2f2a")
const MOSS := Color("5f7c3f")
const SECTION := Color("7a4a18")
const RATE := Color("3f6033")
const RAID := Color("9e3b32")
const SHORT_BG := Color("e7c9c4")

const FONT_DISPLAY := preload("res://ui/fonts/Cinzel-Variable.ttf")
const FONT_BODY := preload("res://ui/fonts/Spectral-Regular.ttf")
const FONT_BODY_SEMI := preload("res://ui/fonts/Spectral-SemiBold.ttf")

## wariacja -> typ bazowy; test sprawdza, że build() tworzy każdą z nich
const VARIATIONS := {
	&"Title": &"Label",
	&"Caption": &"Label",
	&"SectionHeader": &"Label",
	&"Amount": &"Label",
	&"Rate": &"Label",
	&"Badge": &"Label",
	&"BarPanel": &"PanelContainer",
	&"ResCard": &"PanelContainer",
	&"Chip": &"PanelContainer",
	&"Plaque": &"PanelContainer",
	&"Sheet": &"PanelContainer",
	&"ModalHeader": &"PanelContainer",
	&"FleetCard": &"PanelContainer",
	&"Primary": &"Button",
	&"Danger": &"Button",
	&"ToolButton": &"Button",
	&"RaidBar": &"ProgressBar",
	&"ScoutBar": &"ProgressBar",
}

static var _display: FontVariation = null
static var _installed := false


static func px(v: float) -> int:
	return int(roundf(v * SCALE))


static func flat(bg: Color, border: Color, radius: int, border_width: int = 1,
		pad_h: int = 10, pad_v: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(px(radius))
	sb.border_color = border
	sb.set_border_width_all(px(border_width))
	sb.content_margin_left = px(pad_h)
	sb.content_margin_right = px(pad_h)
	sb.content_margin_top = px(pad_v)
	sb.content_margin_bottom = px(pad_v)
	sb.anti_aliasing = true
	return sb


## Rzeźbiona plakietka: pergaminowa twarz, dębowa krawędź, twardy cień pod spodem.
static func plaque(face: Color = PARCHMENT) -> StyleBoxFlat:
	var sb := flat(face, OAK, 5, 2, 8, 8)
	sb.shadow_color = OAK_DEEP
	sb.shadow_size = px(3)
	sb.shadow_offset = Vector2(0, px(3))
	return sb


## Cinzel jest fontem zmiennym; pogrubienie przez oś wght.
static func display_font() -> Font:
	if _display == null:
		_display = FontVariation.new()
		_display.base_font = FONT_DISPLAY
		_display.variation_opentype = {"wght": 700}
	return _display


static func _variation(t: Theme, name: StringName, base: StringName) -> void:
	t.set_type_variation(name, base)


static func build() -> Theme:
	var t := Theme.new()
	var display := display_font()
	var body: Font = FONT_BODY
	var body_semi: Font = FONT_BODY_SEMI
	t.default_font = body
	t.default_font_size = px(15)

	# --- Label ---------------------------------------------------------------
	t.set_font("font", "Label", body)
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", px(15))
	_variation(t, &"Title", &"Label")
	t.set_font("font", "Title", display)
	t.set_color("font_color", "Title", CREAM)
	t.set_font_size("font_size", "Title", px(17))
	_variation(t, &"Caption", &"Label")
	t.set_color("font_color", "Caption", CREAM_SOFT)
	t.set_font_size("font_size", "Caption", px(12))
	_variation(t, &"SectionHeader", &"Label")
	t.set_font("font", "SectionHeader", display)
	t.set_color("font_color", "SectionHeader", SECTION)
	t.set_font_size("font_size", "SectionHeader", px(11))
	_variation(t, &"Amount", &"Label")
	t.set_font("font", "Amount", body_semi)
	t.set_color("font_color", "Amount", INK)
	t.set_font_size("font_size", "Amount", px(14))
	_variation(t, &"Rate", &"Label")
	t.set_color("font_color", "Rate", RATE)
	t.set_font_size("font_size", "Rate", px(11))
	_variation(t, &"Badge", &"Label")
	t.set_font("font", "Badge", display)
	t.set_color("font_color", "Badge", INK)
	t.set_font_size("font_size", "Badge", px(10))
	t.set_stylebox("normal", "Badge", flat(BRASS, BRASS, 2, 0, 5, 3))

	# --- Panele --------------------------------------------------------------
	t.set_stylebox("panel", "PanelContainer", flat(PARCHMENT, OAK_EDGE, 3))
	_variation(t, &"BarPanel", &"PanelContainer")
	var bar := flat(OAK, BRASS, 0, 0, 0, 0)
	bar.border_width_bottom = px(2)
	t.set_stylebox("panel", "BarPanel", bar)
	_variation(t, &"ResCard", &"PanelContainer")
	t.set_stylebox("panel", "ResCard", flat(PARCHMENT, OAK_DEEP, 4, 1, 8, 6))
	_variation(t, &"Chip", &"PanelContainer")
	t.set_stylebox("panel", "Chip", flat(OAK_DEEP, BRASS, 4, 1, 8, 5))
	_variation(t, &"Plaque", &"PanelContainer")
	t.set_stylebox("panel", "Plaque", plaque())
	_variation(t, &"Sheet", &"PanelContainer")
	var sheet := flat(PARCHMENT, BRASS, 0, 0, 14, 14)
	sheet.border_width_top = px(3)
	sheet.shadow_color = Color(0.08, 0.04, 0.0, 0.45)
	sheet.shadow_size = px(16)
	t.set_stylebox("panel", "Sheet", sheet)
	_variation(t, &"ModalHeader", &"PanelContainer")
	t.set_stylebox("panel", "ModalHeader", flat(OAK, OAK, 0, 0, 14, 9))
	_variation(t, &"FleetCard", &"PanelContainer")
	var fleet := flat(PARCHMENT, OAK_EDGE, 3, 1, 11, 10)
	fleet.border_width_left = px(5)
	t.set_stylebox("panel", "FleetCard", fleet)

	# --- Przyciski -----------------------------------------------------------
	t.set_font("font", "Button", display)
	t.set_font_size("font_size", "Button", px(13))
	t.set_color("font_color", "Button", INK_SOFT)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("9a8a70"))
	t.set_stylebox("normal", "Button", flat(Color(0, 0, 0, 0), OAK_EDGE, 4, 1, 14, 14))
	t.set_stylebox("hover", "Button", flat(VELLUM, OAK, 4, 1, 14, 14))
	t.set_stylebox("pressed", "Button", flat(VELLUM, OAK, 4, 1, 14, 14))
	t.set_stylebox("disabled", "Button", flat(Color(0, 0, 0, 0), Color("9a8a70"), 4, 1, 14, 14))
	_variation(t, &"Primary", &"Button")
	t.set_color("font_color", "Primary", INK)
	t.set_color("font_hover_color", "Primary", INK)
	t.set_color("font_pressed_color", "Primary", INK)
	var prim := flat(BRASS, SECTION, 4, 2, 14, 14)
	prim.shadow_color = SECTION
	prim.shadow_size = px(3)
	prim.shadow_offset = Vector2(0, px(3))
	t.set_stylebox("normal", "Primary", prim)
	t.set_stylebox("hover", "Primary", flat(BRASS_HOT, SECTION, 4, 2, 14, 14))
	var prim_down := flat(BRASS_HOT, SECTION, 4, 2, 14, 14)
	prim_down.content_margin_top = px(17)   # 3 px skoku w dół, cień znika
	prim_down.content_margin_bottom = px(11)
	t.set_stylebox("pressed", "Primary", prim_down)
	_variation(t, &"Danger", &"Button")
	t.set_color("font_color", "Danger", BLOOD)
	t.set_color("font_hover_color", "Danger", BLOOD)
	t.set_color("font_pressed_color", "Danger", BLOOD)
	t.set_stylebox("normal", "Danger", flat(Color(0, 0, 0, 0), BLOOD, 4, 2, 14, 14))
	t.set_stylebox("hover", "Danger", flat(SHORT_BG, BLOOD, 4, 2, 14, 14))
	t.set_stylebox("pressed", "Danger", flat(SHORT_BG, BLOOD, 4, 2, 14, 14))
	_variation(t, &"ToolButton", &"Button")      # 46 px dębowe przyciski docku i mapy
	t.set_color("font_color", "ToolButton", CREAM)
	t.set_color("font_hover_color", "ToolButton", CREAM)
	t.set_color("font_pressed_color", "ToolButton", CREAM)
	t.set_font_size("font_size", "ToolButton", px(10))
	t.set_stylebox("normal", "ToolButton", flat(OAK, BRASS, 5, 2, 0, 0))
	t.set_stylebox("hover", "ToolButton", flat(OAK_DEEP, BRASS_HOT, 5, 2, 0, 0))
	t.set_stylebox("pressed", "ToolButton", flat(OAK_DEEP, BRASS_HOT, 5, 2, 0, 0))

	# --- ProgressBar ---------------------------------------------------------
	t.set_stylebox("background", "ProgressBar", flat(RULE, OAK_EDGE, 2, 1, 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(BRASS, BRASS, 2, 0, 0, 0))
	t.set_color("font_color", "ProgressBar", INK_SOFT)
	_variation(t, &"RaidBar", &"ProgressBar")
	t.set_stylebox("fill", "RaidBar", flat(RAID, RAID, 2, 0, 0, 0))
	_variation(t, &"ScoutBar", &"ProgressBar")
	t.set_stylebox("fill", "ScoutBar", flat(RATE, RATE, 2, 0, 0, 0))

	# --- Reszta --------------------------------------------------------------
	t.set_font("font", "LineEdit", body)
	t.set_stylebox("normal", "LineEdit", flat(PARCHMENT, OAK_DEEP, 3, 1, 10, 10))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color("7a6a50"))
	t.set_color("caret_color", "LineEdit", SECTION)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("separator", "HSeparator", flat(OAK_EDGE, OAK_EDGE, 0, 0, 0, 0))
	t.set_constant("separation", "HSeparator", px(1))
	t.set_constant("separation", "VBoxContainer", px(9))
	t.set_constant("separation", "HBoxContainer", px(6))
	return t


## CanvasLayer i Node2D przerywają dziedziczenie motywu, więc zamiast przypinać go do korzenia
## scalamy go z domyślnym motywem silnika: dotyczy wtedy każdej kontrolki w grze.
static func install() -> void:
	if _installed:
		return
	_installed = true
	ThemeDB.get_default_theme().merge_with(build())
	ThemeDB.fallback_font = FONT_BODY
	ThemeDB.fallback_font_size = px(15)
