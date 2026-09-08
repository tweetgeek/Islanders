extends Node

signal view_changed(view_path: String)

const VIEW_WORLD_MAP := "res://scenes/views/WorldMap.tscn"
const VIEW_ISLAND_DETAIL := "res://scenes/views/IslandDetail.tscn"

var current_view: String = ""
var _container: Node = null
var _current: Node = null


func register_container(container: Node) -> void:
	_container = container


func show_world_map() -> void:
	_swap(VIEW_WORLD_MAP)


func show_island_detail() -> void:
	_swap(VIEW_ISLAND_DETAIL)


func _swap(path: String) -> void:
	if _container == null:
		push_error("SceneManager: brak kontenera widoków (register_container)")
		return
	if _current != null:
		_current.queue_free()
	var scene: PackedScene = load(path)
	_current = scene.instantiate()
	_container.add_child(_current)
	current_view = path
	view_changed.emit(path)
