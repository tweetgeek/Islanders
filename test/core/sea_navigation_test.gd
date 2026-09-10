extends GdUnitTestSuite

## Położenia w jednostkach komórek. Przy zerowym przesunięciu położenie wyspy to jej komórka,
## więc te liczby są dokładnie dawnymi odległościami między komórkami.
const A := Vector2(0, 0)
const B := Vector2(4, 0)
const HOME := FixtureCells.HOME
const FOREIGN := FixtureCells.FOREIGN
const SEED := FixtureCells.WORLD_SEED


func test_distance() -> void:
	assert_float(SeaNavigation.distance(A, B)).is_equal(4.0)
	assert_float(SeaNavigation.distance(Vector2(0, 0), Vector2(3, 4))).is_equal(5.0)


func test_distance_is_symmetric() -> void:
	var p := Vector2(80.07, 72.98)
	var q := Vector2(81.1, 72.96)
	assert_float(SeaNavigation.distance(p, q)).is_equal(SeaNavigation.distance(q, p))


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


## ADR 0003: czas podróży liczy się między położeniami wysp, nie między komórkami.
## Koralowa i Szara Skała są sąsiadami w poziomie; ich położenia są odsunięte o ~1,03 komórki.
func test_travel_time_between_measures_island_positions() -> void:
	var a := WorldGrid.island_position(SEED, HOME)
	var b := WorldGrid.island_position(SEED, FOREIGN)
	var got := SeaNavigation.travel_time_between(SEED, HOME, FOREIGN, 4.0)
	assert_float(got).is_equal(SeaNavigation.travel_time(a, b, 4.0))
	# Między komórkami wyszłoby równo 900 s; między położeniami ~926 s.
	assert_float(absf(got - SeaNavigation.travel_time(Vector2(HOME), Vector2(FOREIGN), 4.0))).is_greater(1.0)


## Kierunek wiatru liczy się po tym samym wektorze co odległość. Między komórkami ten wektor
## jest poziomy, więc wiatr z południa byłby neutralny; między położeniami ma składową pionową.
func test_wind_uses_the_vector_between_positions() -> void:
	var calm := SeaNavigation.travel_time_between(SEED, HOME, FOREIGN, 4.0)
	var windy := SeaNavigation.travel_time_between(SEED, HOME, FOREIGN, 4.0, Vector2(0, 1))
	assert_float(absf(windy - calm)).is_greater(0.5)
	var a := WorldGrid.island_position(SEED, HOME)
	var b := WorldGrid.island_position(SEED, FOREIGN)
	assert_float(windy).is_equal(SeaNavigation.travel_time(a, b, 4.0, Vector2(0, 1)))


func test_fleet_speed_is_slowest_ship() -> void:
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10, "GALLEON": 2})).is_equal(4.0)
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10})).is_equal(8.0)
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10, "GALLEON": 0})).is_equal(8.0)
	assert_float(SeaNavigation.fleet_speed({})).is_equal(0.0)
	assert_float(SeaNavigation.fleet_speed({"UNKNOWN": 3})).is_equal(0.0)
