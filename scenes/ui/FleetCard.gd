class_name FleetCard
extends PanelContainer

## Karta jednej floty: misja i cel, odliczanie, pasek postępu, skład. Lewa krawędź w kolorze misji.

signal tapped(fleet: Fleet)

const ICON := 16.0
const SHIP_LABELS := {"SLOOP": "slup", "GALLEON": "galeon"}

@onready var mission_icon: Icon = $VBox/HeaderRow/MissionIcon
@onready var title: Label = $VBox/HeaderRow/Title
@onready var eta_label: Label = $VBox/HeaderRow/EtaLabel
@onready var eta_bar: ProgressBar = $VBox/EtaBar
@onready var composition: Label = $VBox/Composition

var fleet: Fleet = null


func _ready() -> void:
	mission_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
	title.add_theme_color_override("font_color", MedievalTheme.INK)
	composition.add_theme_color_override("font_color", MedievalTheme.INK_SOFT)
	eta_bar.custom_minimum_size.y = MedievalTheme.px(8)
	gui_input.connect(_on_gui_input)


func refresh(f: Fleet, now: float, player_id: int) -> void:
	fleet = f
	var label: String = Fleet.MISSION_LABELS.get(f.mission, f.mission)
	title.text = "%s → (%d, %d)" % [label, f.to.x, f.to.y]
	eta_label.text = TimeUtil.format_eta(f.remaining_seconds(now))
	eta_bar.value = f.progress(now)
	composition.text = _composition(f) if f.is_own(player_id) else "gracz %d · szczegóły niewidoczne" % f.owner_id
	mission_icon.kind = Fleet.MISSION_ICONS.get(f.mission, &"fleet")
	var accent := MedievalTheme.BRASS
	var bar_variation := &""
	match f.mission:
		"ATTACK":
			accent = MedievalTheme.BLOOD
			bar_variation = &"RaidBar"
		"EXPEDITION":
			accent = MedievalTheme.MOSS
			bar_variation = &"ScoutBar"
	eta_bar.theme_type_variation = bar_variation
	mission_icon.color = accent
	var base := get_theme_stylebox("panel")
	if base is StyleBoxFlat:
		var sb: StyleBoxFlat = base.duplicate()
		sb.border_color = accent
		add_theme_stylebox_override("panel", sb)


func _composition(f: Fleet) -> String:
	var parts: Array[String] = []
	for k in f.ships:
		parts.append("%d × %s" % [int(f.ships[k]), SHIP_LABELS.get(k, k)])
	for k in f.cargo_units:
		parts.append("%d × %s" % [int(f.cargo_units[k]), k])
	for r in ResourceTypes.ALL:
		var amount := float(f.cargo_resources.get(r, 0.0))
		if amount > 0.0:
			parts.append("%s %s" % [TimeUtil.format_thousands(amount), ResourceTypes.LABELS[r].to_lower()])
	return " · ".join(parts)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and fleet != null:
		tapped.emit(fleet)
