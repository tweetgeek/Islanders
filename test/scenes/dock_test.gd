extends GdUnitTestSuite

const DOCK := preload("res://scenes/ui/Dock.tscn")


func before_test() -> void:
	GameState.reset()
	GameState.apply_world(FixtureCells.world_json())


func after_test() -> void:
	GameState.reset()


func _fleet(id: String, owner: int, arrive_in: float) -> Dictionary:
	var now := TimeUtil.now()
	return {
		"id": id, "ownerId": owner, "mission": "ATTACK",
		"from": {"x": 0, "y": 0}, "to": {"x": 4, "y": 0},
		"departAt": TimeUtil.to_iso8601(now - 60.0), "arriveAt": TimeUtil.to_iso8601(now + arrive_in),
	}


func _dock() -> CanvasLayer:
	var d: CanvasLayer = auto_free(DOCK.instantiate())
	add_child(d)
	return d


func test_badge_counts_fleets_in_transit() -> void:
	var d := _dock()
	assert_bool(d.badge.visible).is_false()
	GameState.apply_fleets([_fleet("a", 7, 600.0), _fleet("b", 7, -5.0)])
	assert_bool(d.badge.visible).is_true()
	assert_str(d.badge.text).is_equal("1")
	assert_bool(d.is_alarmed()).is_false()


func test_incoming_foreign_fleet_alarms_badge() -> void:
	var d := _dock()
	GameState.apply_fleets([_fleet("a", 9, 600.0)])
	assert_bool(d.is_alarmed()).is_true()


func test_map_button_only_in_settlement_view() -> void:
	var d := _dock()
	SceneManager.view_changed.emit(SceneManager.VIEW_ISLAND_DETAIL)
	assert_bool(d.map_button.visible).is_true()
	SceneManager.view_changed.emit(SceneManager.VIEW_WORLD_MAP)
	assert_bool(d.map_button.visible).is_false()


func test_dock_buttons_sit_one_gap_from_the_edge() -> void:
	var d := _dock()
	await await_idle_frame()
	assert_float(d.fleets_button.position.x).is_equal(float(MedievalTheme.gap(d.MARGIN)))
