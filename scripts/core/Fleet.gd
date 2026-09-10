class_name Fleet
extends RefCounted

## Prędkości w komórkach na godzinę. Do czasu, aż typów będzie więcej, tabela żyje tutaj.
const SHIP_SPEED := {"SLOOP": 8.0, "GALLEON": 4.0}
const MISSIONS: Array[String] = ["COLONIZE", "ATTACK", "TRANSPORT", "EXPEDITION", "RETURN"]

const MISSION_LABELS := {
	"COLONIZE": "Kolonizacja",
	"ATTACK": "Atak",
	"TRANSPORT": "Transport",
	"EXPEDITION": "Wyprawa",
	"RETURN": "Powrót",
}

const MISSION_ICONS := {
	"COLONIZE": &"colonize",
	"ATTACK": &"raid",
	"TRANSPORT": &"trade",
	"EXPEDITION": &"scout",
	"RETURN": &"return",
}

var id: String = ""
var world_id: String = ""
var owner_id: int = 0
var mission: String = "TRANSPORT"
var from: Vector2i = Coord.NONE
var to: Vector2i = Coord.NONE
## typ statku -> liczba; puste dla nadchodzącej cudzej floty
var ships: Dictionary = {}
var cargo_units: Dictionary = {}
var cargo_resources: Dictionary = {}
var depart_at: float = 0.0
var arrive_at: float = 0.0


## Zwraca null, gdy brakuje id, from lub to.
static func from_json(d: Dictionary) -> Fleet:
	var f := Fleet.new()
	f.id = str(d.get("id", ""))
	f.from = Coord.from_json(d.get("from"))
	f.to = Coord.from_json(d.get("to"))
	if f.id.is_empty() or f.from == Coord.NONE or f.to == Coord.NONE:
		push_warning("Fleet: rekord bez id/from/to odrzucony")
		return null
	f.world_id = str(d.get("world", ""))
	f.owner_id = int(d.get("ownerId", 0))
	f.mission = str(d.get("mission", "TRANSPORT"))
	if not MISSIONS.has(f.mission):
		push_warning("Fleet %s: nieznana misja '%s'" % [f.id, f.mission])
	var ships: Variant = d.get("ships", {})
	if ships is Dictionary:
		for k in ships.keys():
			f.ships[str(k)] = int(ships[k])
	var cargo: Variant = d.get("cargo", {})
	if cargo is Dictionary:
		var units: Variant = cargo.get("units", {})
		if units is Dictionary:
			for k in units.keys():
				f.cargo_units[str(k)] = int(units[k])
		f.cargo_resources = ResourceTypes.normalize(cargo.get("resources", {}))
	f.depart_at = TimeUtil.parse_iso8601(str(d.get("departAt", "1970-01-01T00:00:00Z")))
	f.arrive_at = TimeUtil.parse_iso8601(str(d.get("arriveAt", "1970-01-01T00:00:00Z")))
	return f


func progress(now: float) -> float:
	var total := arrive_at - depart_at
	if total <= 0.0:
		return 1.0
	return clampf((now - depart_at) / total, 0.0, 1.0)


## Pozycja na mapie w chwili now, między środkami wysp startu i celu (WorldGrid.island_center),
## żeby trasa zaczynała się i kończyła na wyspach, a nie obok nich. Flota zna identyfikator
## świata, ale nie jego ziarno, więc podaje je wołający (GameState.world_seed()).
func position_at(now: float, world_seed: int) -> Vector2:
	return WorldGrid.island_center(world_seed, from).lerp(WorldGrid.island_center(world_seed, to), progress(now))


func direction(world_seed: int) -> Vector2:
	return (WorldGrid.island_center(world_seed, to) - WorldGrid.island_center(world_seed, from)).normalized()


func is_arrived(now: float) -> bool:
	return now >= arrive_at


func is_own(player_id: int) -> bool:
	return owner_id == player_id


func total_ships() -> int:
	var n := 0
	for k in ships:
		n += int(ships[k])
	return n


func remaining_seconds(now: float) -> float:
	return maxf(arrive_at - now, 0.0)
