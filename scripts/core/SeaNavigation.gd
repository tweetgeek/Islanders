class_name SeaNavigation
extends RefCounted

const WIND_FACTOR := 0.5
const WIND_MIN := 0.5
const WIND_MAX := 1.5


static func distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


## Prędkość najwolniejszego znanego typu statku; 0.0 gdy flota pusta lub same nieznane typy.
static func fleet_speed(ships: Dictionary) -> float:
	var speed := INF
	for k in ships:
		if int(ships[k]) > 0 and Fleet.SHIP_SPEED.has(k):
			speed = minf(speed, Fleet.SHIP_SPEED[k])
	return 0.0 if speed == INF else speed


## Czas podróży w sekundach. Wiatr działa przez składową wzdłuż kierunku, ograniczoną do [0.5, 1.5] prędkości.
static func travel_time(a: Vector2i, b: Vector2i, speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float:
	var d := distance(a, b)
	if d == 0.0:
		return 0.0
	if speed_cells_per_hour <= 0.0:
		return INF
	var dir := Vector2(b - a).normalized()
	var factor := clampf(1.0 + WIND_FACTOR * wind.dot(dir), WIND_MIN, WIND_MAX)
	return d / (speed_cells_per_hour * factor) * 3600.0
