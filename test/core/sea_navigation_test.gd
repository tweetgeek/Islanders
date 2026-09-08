extends GdUnitTestSuite

const A := Vector2i(0, 0)
const B := Vector2i(4, 0)


func test_distance() -> void:
	assert_float(SeaNavigation.distance(A, B)).is_equal(4.0)
	assert_float(SeaNavigation.distance(Vector2i(0, 0), Vector2i(3, 4))).is_equal(5.0)


func test_zero_distance_is_zero_time() -> void:
	assert_float(SeaNavigation.travel_time(A, A, 4.0)).is_equal(0.0)


func test_calm_sea() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0)).is_equal(3600.0)


func test_tailwind_shortens() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(1, 0))).is_equal(2400.0)


func test_headwind_lengthens() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(-1, 0))).is_equal(7200.0)


func test_crosswind_neutral() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(0, 1))).is_equal(3600.0)


func test_wind_is_clamped() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(5, 0))).is_equal(2400.0)
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(-5, 0))).is_equal(7200.0)


func test_zero_speed_is_infinite() -> void:
	assert_bool(is_inf(SeaNavigation.travel_time(A, B, 0.0))).is_true()


func test_fleet_speed_is_slowest_ship() -> void:
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10, "GALLEON": 2})).is_equal(4.0)
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10})).is_equal(8.0)
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10, "GALLEON": 0})).is_equal(8.0)
	assert_float(SeaNavigation.fleet_speed({})).is_equal(0.0)
	assert_float(SeaNavigation.fleet_speed({"UNKNOWN": 3})).is_equal(0.0)
