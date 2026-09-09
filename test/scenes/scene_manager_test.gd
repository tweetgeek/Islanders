extends GdUnitTestSuite

## Nawigacja SceneManagera: obie gałęzie show_world_map_at, brak przebudowy przy ponownym
## otwarciu tego samego widoku i fade wchodzącego widoku.
## SceneManager to autoload, więc każdy test sprząta po sobie stan globalny.

var _container: Node = null


func before_test() -> void:
	GameState.reset()
	GameState.apply_world(FixtureCells.world_json())
	SceneManager.map_camera_state.clear()
	_container = Node.new()
	add_child(_container)
	SceneManager.register_container(_container)


func after_test() -> void:
	# Kolejność ma znaczenie: najpierw zrywamy referencje autoloadu, potem zwalniamy węzły.
	SceneManager._current = null
	SceneManager.current_view = ""
	SceneManager.register_container(null)
	SceneManager.map_camera_state.clear()
	if is_instance_valid(_container):
		_container.queue_free()
	_container = null
	GameState.reset()


func _view() -> Node:
	return _container.get_child(0) if _container.get_child_count() > 0 else null


func _camera_of(view: Node) -> MapCamera:
	return view.get_node("Camera") as MapCamera


func test_show_world_map_at_records_position_and_opens_the_map() -> void:
	var target := WorldGrid.cell_to_world(FixtureCells.DEPOSIT)
	SceneManager.show_world_map_at(target)
	assert_str(SceneManager.current_view).is_equal(SceneManager.VIEW_WORLD_MAP)
	assert_that(SceneManager.map_camera_state.get("position")).is_equal(target)
	var view := _view()
	assert_object(view).is_not_null()
	assert_that(_camera_of(view).position).is_equal(target)


func test_show_world_map_at_moves_the_open_map_without_rebuilding_it() -> void:
	SceneManager.show_world_map()
	var first := _view()
	assert_object(first).is_not_null()
	var target := WorldGrid.cell_to_world(FixtureCells.FOREIGN)
	SceneManager.show_world_map_at(target)
	assert_int(_container.get_child_count()).is_equal(1)
	assert_bool(_view() == first).is_true()
	assert_that(_camera_of(first).position).is_equal(target)


func test_requesting_the_current_view_again_does_not_rebuild_it() -> void:
	SceneManager.show_world_map()
	var first := _view()
	SceneManager.show_world_map()
	assert_int(_container.get_child_count()).is_equal(1)
	assert_bool(_view() == first).is_true()


func test_incoming_view_fades_in() -> void:
	SceneManager.show_world_map()
	var view := _view() as CanvasItem
	assert_float(view.modulate.a).is_less(1.0)
	await await_millis(int(SceneManager.FADE_TIME * 1000.0) + 150)
	assert_float(view.modulate.a).is_equal_approx(1.0, 0.001)
