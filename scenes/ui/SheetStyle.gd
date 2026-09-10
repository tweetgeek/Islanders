class_name SheetStyle
extends RefCounted

## Wspólne ustawienia arkuszy od dołu: margines, separacja, uchwyt i cały nagłówek
## (ikona, przycisk zamknięcia i jego podpięcie). Każdy arkusz woła to raz w _ready(),
## a potem robi już tylko to, co ma naprawdę własnego.

const MARGIN := 14.0
const GRABBER := Vector2(44.0, 4.0)
const CLOSE := 30.0
const CHIP_ICON := 13.0


## icon_size różni się między arkuszami (wyższy nagłówek unosi większą ikonę), więc jest
## argumentem, a nie stałą powtórzoną w każdym arkuszu.
static func apply_common(sheet: PanelContainer, grabber: Panel, header_icon: Icon,
		close_button: Button, close_requested: Signal, icon_size: float) -> void:
	var margin: MarginContainer = sheet.get_node("SheetMargin")
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MedievalTheme.gap(MARGIN))
	(margin.get_node("Body") as Control).add_theme_constant_override("separation", MedievalTheme.gap(11))
	grabber.custom_minimum_size = Vector2(MedievalTheme.px(GRABBER.x), MedievalTheme.px(GRABBER.y))
	grabber.add_theme_stylebox_override("panel", MedievalTheme.flat(MedievalTheme.OAK_EDGE, MedievalTheme.OAK_EDGE, 2, 0, 0, 0))
	header_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(icon_size)
	header_icon.color = MedievalTheme.CREAM
	header_icon.knockout = MedievalTheme.OAK   # nagłówek ModalHeader ma tło OAK
	close_button.custom_minimum_size = Vector2.ONE * MedievalTheme.px(CLOSE)
	Icon.into_button(close_button, &"close", MedievalTheme.CREAM, MedievalTheme.px(7))
	close_button.pressed.connect(func() -> void: close_requested.emit())


## Chip zasobu: ikona w kolorze zasobu plus etykieta kwoty. Używają go arkusz budynku
## (koszt ulepszenia) i arkusz oglądanej wyspy (zawartość znaleziska), więc konstrukcja
## mieszka w jednym miejscu; wołający ustawia tekst i ewentualne nadpisania stylu.
static func resource_chip(resource: String, icon_size: float = CHIP_ICON) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Icon.new()
	icon.name = "Icon"
	icon.kind = ResourceTypes.ICONS[resource]
	icon.color = ResourceTypes.COLORS[resource]
	icon.knockout = MedievalTheme.OAK_DEEP   # tło wariacji Chip
	icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(icon_size)
	var amount := Label.new()
	amount.name = "Amount"
	amount.theme_type_variation = &"Amount"
	box.add_child(icon)
	box.add_child(amount)
	chip.add_child(box)
	return chip


## Etykieta kwoty w chipie zbudowanym przez resource_chip().
static func chip_amount(chip: PanelContainer) -> Label:
	return chip.get_node("Box/Amount") as Label


## Ikona zasobu w chipie zbudowanym przez resource_chip(); wołający, który przemalowuje tło
## chipa, musi przestawić też jej wycięcie.
static func chip_icon(chip: PanelContainer) -> Icon:
	return chip.get_node("Box/Icon") as Icon
