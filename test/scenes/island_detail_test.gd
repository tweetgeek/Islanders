extends GdUnitTestSuite

## Testy IslandDetail.gd. Skupione na odporności obsługi dotyku na drugi palec: widok obsługuje
## wyłącznie tapnięcie, więc drugi palec nie może przejąć ani zepsuć gestu pierwszego
## (MapCamera rozwiązuje ten sam problem przez _touches, patrz map_camera_test.gd).

const ISLAND_DETAIL_SCENE := preload("res://scenes/views/IslandDetail.tscn")
const SHEETS_SCENE := preload("res://scenes/ui/Sheets.tscn")
const HOME := FixtureCells.HOME


func before_test() -> void:
	GameState.reset()
	GameState.apply_world(FixtureCells.world_json())
	GameState.apply_settlements([{
		"x": HOME.x, "y": HOME.y, "ownerId": 7, "name": "Koralowa",
		"resources": {}, "buildings": {},
	}])
	GameState.set_active_settlement(HOME)


func after_test() -> void:
	GameState.reset()


func _detail() -> Node2D:
	var det: Node2D = auto_free(ISLAND_DETAIL_SCENE.instantiate())
	add_child(det)
	return det


func _sheets() -> CanvasLayer:
	var s: CanvasLayer = auto_free(SHEETS_SCENE.instantiate())
	add_child(s)
	return s


## Pozycja slotu w pikselach ekranu (viewportu), jak liczy to tools/smoke_probe.gd.
func _slot_point(det: Node2D, gen: IslandGenerator, t: Buildings.Type) -> Vector2:
	var world_pos: Vector2 = gen.to_global(gen._slot_positions[t])
	return det.get_canvas_transform() * world_pos


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _plaque(gen: IslandGenerator, t: Buildings.Type) -> SlotPlaque:
	return gen.get_node("Slot_" + Buildings.key(t))


func test_second_finger_does_not_steal_or_corrupt_the_first_gesture() -> void:
	var sheets := _sheets()
	var det := _detail()
	await await_idle_frame()
	var gen: IslandGenerator = det.generator
	var hall_pos := _slot_point(det, gen, Buildings.Type.TOWN_HALL)
	var sawmill_pos := _slot_point(det, gen, Buildings.Type.SAWMILL)

	det._unhandled_input(_touch(0, hall_pos, true))
	assert_bool(_plaque(gen, Buildings.Type.TOWN_HALL).pressed).is_true()

	det._unhandled_input(_touch(1, sawmill_pos, true))
	assert_bool(_plaque(gen, Buildings.Type.SAWMILL).pressed).is_false()
	assert_bool(_plaque(gen, Buildings.Type.TOWN_HALL).pressed).is_true()

	det._unhandled_input(_touch(1, sawmill_pos, false))
	assert_bool(_plaque(gen, Buildings.Type.TOWN_HALL).pressed).is_true()
	assert_bool(sheets.is_open()).is_false()

	det._unhandled_input(_touch(0, hall_pos, false))
	assert_bool(_plaque(gen, Buildings.Type.TOWN_HALL).pressed).is_false()
	assert_bool(sheets.is_open()).is_true()
