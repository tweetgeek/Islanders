extends GdUnitTestSuite

const GameStateScript := preload("res://scenes/autoload/GameState.gd")


func _state() -> Node:
	var gs: Node = auto_free(GameStateScript.new())
	gs.apply_world(
		{
			"id": "w1",
			"seed": 1337,
			"size": {"w": 200, "h": 200},
			"playerId": 7,
			"homeSettlement": {"x": 103, "y": 100},
		}
	)
	return gs


func _own(x: int, y: int) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"ownerId": 7,
		"name": "A",
		"resources": {},
		"productionPerHour": {},
		"capacity": 100,
		"lastSyncAt": "2026-09-07T12:00:00Z",
	}


func test_apply_world_sets_player() -> void:
	var gs := _state()
	assert_int(gs.player_id).is_equal(7)
	assert_that(gs.world.home_settlement).is_equal(Vector2i(103, 100))


func test_settlement_on_sea_is_rejected() -> void:
	var gs := _state()
	gs.apply_settlements([_own(100, 100)])
	assert_int(gs.settlements.size()).is_equal(0)


func test_settlement_on_land_is_stored_with_biome() -> void:
	var gs := _state()
	gs.apply_settlements([_own(103, 100)])
	var s: Settlement = gs.settlement_at(Vector2i(103, 100))
	assert_object(s).is_not_null()
	assert_int(s.biome).is_equal(Biome.Type.TROPICAL)


func test_finish_loading_activates_home() -> void:
	var gs := _state()
	gs.apply_settlements([_own(103, 100)])
	gs.finish_loading()
	assert_object(gs.active_settlement).is_not_null()
	assert_that(gs.active_settlement.coord).is_equal(Vector2i(103, 100))


func test_cannot_activate_foreign_settlement() -> void:
	var gs := _state()
	gs.apply_settlements([{"x": 95, "y": 100, "ownerId": 9, "name": "Obca"}])
	assert_bool(gs.set_active_settlement(Vector2i(95, 100))).is_false()
	assert_object(gs.active_settlement).is_null()


func test_apply_settlements_refreshes_active_reference() -> void:
	var gs := _state()
	gs.apply_settlements([_own(103, 100)])
	gs.finish_loading()
	var updated := _own(103, 100)
	updated["name"] = "Nowa"
	gs.apply_settlements([updated])
	assert_str(gs.active_settlement.name).is_equal("Nowa")


func test_apply_fleets_replaces_all() -> void:
	var gs := _state()
	gs.apply_fleets([{"id": "f1", "from": {"x": 0, "y": 0}, "to": {"x": 1, "y": 1}}, {"id": "bad"}])
	assert_int(gs.fleets.size()).is_equal(1)
	gs.apply_fleets([])
	assert_int(gs.fleets.size()).is_equal(0)


func test_inspect_emits_signal() -> void:
	var gs := _state()
	var received: Array = []
	gs.inspected_island_changed.connect(func(c: Vector2i) -> void: received.append(c))
	gs.inspect(Vector2i(5, 6))
	assert_that(gs.inspected_coord).is_equal(Vector2i(5, 6))
	assert_that(received).is_equal([Vector2i(5, 6)])


func test_island_at_out_of_bounds_is_null() -> void:
	var gs := _state()
	assert_object(gs.island_at(Vector2i(500, 500))).is_null()


func test_apply_settlements_before_apply_world_is_rejected() -> void:
	var gs: Node = auto_free(GameStateScript.new())
	gs.apply_settlements([_own(103, 100)])
	assert_int(gs.settlements.size()).is_equal(0)


func test_apply_settlements_emits_settlement_updated_per_accepted_record() -> void:
	var gs := _state()
	var received: Array = []
	gs.settlement_updated.connect(func(c: Vector2i) -> void: received.append(c))
	gs.apply_settlements([_own(103, 100), {"x": 95, "y": 100, "ownerId": 9, "name": "Obca"}])
	assert_that(received).is_equal([Vector2i(103, 100), Vector2i(95, 100)])


func test_apply_fleets_emits_fleets_updated() -> void:
	var gs := _state()
	var received: Array = []
	gs.fleets_updated.connect(func() -> void: received.append(true))
	gs.apply_fleets([{"id": "f1", "from": {"x": 0, "y": 0}, "to": {"x": 1, "y": 1}}])
	assert_that(received).is_equal([true])


func test_finish_loading_emits_state_loaded() -> void:
	var gs := _state()
	var received: Array = []
	gs.state_loaded.connect(func() -> void: received.append(true))
	gs.finish_loading()
	assert_that(received).is_equal([true])


func test_set_active_settlement_emits_active_settlement_changed() -> void:
	var gs := _state()
	gs.apply_settlements([_own(103, 100)])
	var received: Array = []
	gs.active_settlement_changed.connect(func() -> void: received.append(true))
	assert_bool(gs.set_active_settlement(Vector2i(103, 100))).is_true()
	assert_that(received).is_equal([true])


func test_foreign_settlement_rejection_does_not_emit_active_settlement_changed() -> void:
	var gs := _state()
	gs.apply_settlements([{"x": 95, "y": 100, "ownerId": 9, "name": "Obca"}])
	var received: Array = []
	gs.active_settlement_changed.connect(func() -> void: received.append(true))
	assert_bool(gs.set_active_settlement(Vector2i(95, 100))).is_false()
	assert_that(received).is_equal([])
