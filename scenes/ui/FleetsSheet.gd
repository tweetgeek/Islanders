class_name FleetsSheet
extends PanelContainer

## Lista flot: nadchodzące cudze na górze, własne w drodze poniżej, przybyłe pomijane.
## Karty odświeżane co sekundę, tylko gdy arkusz jest widoczny.

signal fleet_tapped(fleet: Fleet)
signal close_requested

const FLEET_CARD := preload("res://scenes/ui/FleetCard.tscn")
const TICK := 1.0

@onready var grabber: Panel = $SheetMargin/Body/Grabber
@onready var fleet_icon: Icon = $SheetMargin/Body/Header/HBox/FleetIcon
@onready var close_button: Button = $SheetMargin/Body/Header/HBox/CloseButton
@onready var list: VBoxContainer = $SheetMargin/Body/Scroll/List
@onready var incoming_header: Label = $SheetMargin/Body/Scroll/List/IncomingHeader
@onready var own_header: Label = $SheetMargin/Body/Scroll/List/OwnHeader
@onready var empty_label: Label = $SheetMargin/Body/Scroll/List/EmptyLabel

var _cards: Array = []
var _accum := 0.0


func _ready() -> void:
	SheetStyle.apply_common(self, grabber, fleet_icon, close_button, close_requested, 40.0)
	list.add_theme_constant_override("separation", MedievalTheme.px(10))
	GameState.fleets_updated.connect(_on_fleets_updated)


func cards() -> Array:
	return _cards.duplicate()


func refresh() -> void:
	for c in _cards:
		list.remove_child(c)
		c.queue_free()
	_cards.clear()
	var now := TimeUtil.now()
	var pid := GameState.player_id
	var incoming: Array = []
	var own: Array = []
	for f: Fleet in GameState.fleets.values():
		if f.is_arrived(now):
			continue
		if f.is_own(pid):
			own.append(f)
		else:
			incoming.append(f)
	var by_arrival := func(a: Fleet, b: Fleet) -> bool: return a.arrive_at < b.arrive_at
	incoming.sort_custom(by_arrival)
	own.sort_custom(by_arrival)
	incoming_header.visible = not incoming.is_empty()
	incoming_header.text = "NADCHODZĄCE · %d" % incoming.size()
	own_header.visible = not own.is_empty()
	own_header.text = "W DRODZE · %d" % own.size()
	empty_label.visible = incoming.is_empty() and own.is_empty()
	_insert_cards(incoming, incoming_header, now, pid)
	_insert_cards(own, own_header, now, pid)


## Karty wchodzą zaraz za swoim nagłówkiem, w kolejności przybycia.
func _insert_cards(fleets: Array, header: Label, now: float, pid: int) -> void:
	var index := header.get_index() + 1
	for f: Fleet in fleets:
		var card: FleetCard = FLEET_CARD.instantiate()
		list.add_child(card)
		list.move_child(card, index)
		index += 1
		card.refresh(f, now, pid)
		card.tapped.connect(func(x: Fleet) -> void: fleet_tapped.emit(x))
		_cards.append(card)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_accum += delta
	if _accum < TICK:
		return
	_accum = 0.0
	var now := TimeUtil.now()
	for c: FleetCard in _cards:
		# Podziału na sekcje i liczb w nagłówkach tik sam nie poprawi - to robi refresh().
		if c.fleet.is_arrived(now):
			refresh()
			return
	for c: FleetCard in _cards:
		c.refresh_countdown(now)


func _on_fleets_updated() -> void:
	if is_visible_in_tree():
		refresh()
