class_name SeaNavigation
extends RefCounted

const WIND_FACTOR := 0.5
const WIND_MIN := 0.5
const WIND_MAX := 1.5


## Odległość w komórkach między dwoma położeniami wysp (WorldGrid.island_position).
static func distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)


## Prędkość najwolniejszego znanego typu statku; 0.0 gdy flota pusta lub same nieznane typy.
static func fleet_speed(ships: Dictionary) -> float:
	var speed := INF
	for k in ships:
		if int(ships[k]) > 0 and Fleet.SHIP_SPEED.has(k):
			speed = minf(speed, Fleet.SHIP_SPEED[k])
	return 0.0 if speed == INF else speed


## Czas podróży w sekundach między dwoma położeniami. Wiatr działa przez składową wzdłuż kierunku
## podróży - wektora między tymi samymi położeniami - ograniczoną do [0.5, 1.5] prędkości.
## Czysta geometria; skąd biorą się położenia, decyduje travel_time_between.
static func travel_time(a: Vector2, b: Vector2, speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float:
	var d := distance(a, b)
	if d == 0.0:
		return 0.0
	if speed_cells_per_hour <= 0.0:
		return INF
	var dir := (b - a).normalized()
	var factor := clampf(1.0 + WIND_FACTOR * wind.dot(dir), WIND_MIN, WIND_MAX)
	return d / (speed_cells_per_hour * factor) * 3600.0


## Czas podróży między dwiema wyspami świata (ADR 0003): odległość między ich położeniami,
## nie między komórkami. Podgląd dla gracza - czas przybycia liczy i zamraża serwer; położenia
## są tu float32 (Vector2), co daje dokładność ułamka sekundy, nie bit w bit.
static func travel_time_between(world_seed: int, from_cell: Vector2i, to_cell: Vector2i,
		speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float:
	return travel_time(
		WorldGrid.island_position(world_seed, from_cell),
		WorldGrid.island_position(world_seed, to_cell),
		speed_cells_per_hour, wind
	)
