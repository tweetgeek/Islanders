extends Node

## Jedyne źródło prawdy o stanie gry po stronie klienta. Mutacje tylko przez metody apply_* / set_* / inspect.

signal state_loaded
signal settlement_updated(coord: Vector2i)
signal fleets_updated
signal active_settlement_changed
signal inspected_island_changed(coord: Vector2i)

var world: GameWorld = null
var player_id: int = 0
## Coord.key -> Settlement
var settlements: Dictionary = {}
## id -> Fleet
var fleets: Dictionary = {}
var active_settlement: Settlement = null
var inspected_coord: Vector2i = Coord.NONE


func apply_world(d: Dictionary) -> void:
	world = GameWorld.from_json(d)
	player_id = world.player_id


func apply_settlements(arr: Array) -> void:
	if world == null:
		push_error("GameState: apply_settlements przed apply_world")
		return
	for d in arr:
		if not (d is Dictionary):
			continue
		var coord := Coord.from_json(d)
		var island := island_at(coord)
		if island == null:
			push_error("GameState: osada na %s, a WorldGrid uznaje tę komórkę za morze; rekord odrzucony (ADR 0001)" % coord)
			continue
		var s := Settlement.from_json(d, island.biome)
		if s == null:
			continue
		settlements[Coord.key(coord)] = s
		if active_settlement != null and active_settlement.coord == coord:
			if s.is_own:
				active_settlement = s
			else:
				# Osada aktywna zawsze musi być własna (CONTEXT.md): utracona -> cofamy się do
				# domowej, jeśli wciąż nasza, inaczej brak aktywnej osady.
				var previous := active_settlement
				active_settlement = null
				if world.home_settlement != Coord.NONE:
					var home := settlement_at(world.home_settlement)
					if home != null and home.is_own:
						active_settlement = home
				if active_settlement != previous:
					active_settlement_changed.emit()
		settlement_updated.emit(coord)


func apply_fleets(arr: Array) -> void:
	fleets.clear()
	for d in arr:
		if not (d is Dictionary):
			continue
		var f := Fleet.from_json(d)
		if f != null:
			fleets[f.id] = f
	fleets_updated.emit()


## Wołane po pierwszym pełnym załadowaniu: osada domowa staje się aktywna, o ile już ją mamy
## (nieudany fetch osad zostawia settlements puste — wtedy nie ma czego aktywować i to nie błąd;
## kolejny resync ją uzupełni).
func finish_loading() -> void:
	if world != null and active_settlement == null and settlement_at(world.home_settlement) != null:
		set_active_settlement(world.home_settlement)
	state_loaded.emit()


## Zwraca false dla morza, wyspy bez osady i osady cudzej.
func set_active_settlement(coord: Vector2i) -> bool:
	var s := settlement_at(coord)
	if s == null or not s.is_own:
		push_error("GameState: %s nie jest własną osadą" % coord)
		return false
	active_settlement = s
	active_settlement_changed.emit()
	return true


func inspect(coord: Vector2i) -> void:
	inspected_coord = coord
	inspected_island_changed.emit(coord)


func settlement_at(coord: Vector2i) -> Settlement:
	return settlements.get(Coord.key(coord), null)


func island_at(coord: Vector2i) -> Island:
	if world == null or not world.in_bounds(coord):
		return null
	return WorldGrid.island_at(world.seed_val, coord)


## Ziarno świata albo 0, gdy świata jeszcze nie ma. Rysowanie mapy i flot pyta o nie co klatkę,
## także zanim przyjdzie stan, więc zabezpieczenie żyje tu, a nie w każdym wołającym.
func world_seed() -> int:
	return world.seed_val if world != null else 0


func own_settlements() -> Array:
	var out: Array = []
	for s in settlements.values():
		if s.is_own:
			out.append(s)
	return out


## Tylko dla testów: przywraca stan początkowy.
func reset() -> void:
	world = null
	player_id = 0
	settlements.clear()
	fleets.clear()
	active_settlement = null
	inspected_coord = Coord.NONE
