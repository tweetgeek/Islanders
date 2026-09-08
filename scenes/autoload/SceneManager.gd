extends Node

signal view_changed(view_path: String)

const VIEW_WORLD_MAP := "res://scenes/views/WorldMap.tscn"
const VIEW_ISLAND_DETAIL := "res://scenes/views/IslandDetail.tscn"
const FADE_TIME := 0.18

var current_view: String = ""
## Ostatnia pozycja i zoom kamery mapy: WorldMap zapisuje przy wyjściu, odczytuje przy wejściu.
## Pusty słownik = mapa centruje na osadzie aktywnej.
var map_camera_state: Dictionary = {}
var _container: Node = null
var _current: Node = null
var _fade: Tween = null


func register_container(container: Node) -> void:
	_container = container


func show_world_map() -> void:
	_swap(VIEW_WORLD_MAP)


func show_island_detail() -> void:
	_swap(VIEW_ISLAND_DETAIL)


## Otwiera mapę wycentrowaną na punkcie świata; gdy mapa już jest otwarta, tylko przesuwa kamerę.
func show_world_map_at(world_pos: Vector2) -> void:
	if current_view == VIEW_WORLD_MAP and _current != null:
		_current.focus(world_pos)
		return
	map_camera_state["position"] = world_pos
	_swap(VIEW_WORLD_MAP)


func _swap(path: String) -> void:
	if _container == null:
		push_error("SceneManager: brak kontenera widoków (register_container)")
		return
	if path == current_view and _current != null:
		return
	if _current != null:
		_current.queue_free()
	var scene: PackedScene = load(path)
	_current = scene.instantiate()
	_container.add_child(_current)
	current_view = path
	_fade_in(_current)
	view_changed.emit(path)


## Wchodzący widok pojawia się przez fade; wychodzący znika od razu (tween na węźle
## czekającym na queue_free to źródło błędów, a przy fade wchodzącego różnicy nie widać).
func _fade_in(view: Node) -> void:
	if not (view is CanvasItem):
		return
	if _fade != null and _fade.is_running():
		_fade.kill()
	view.modulate.a = 0.0
	_fade = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade.tween_property(view, "modulate:a", 1.0, FADE_TIME)
