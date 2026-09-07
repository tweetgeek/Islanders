class_name Settlement
extends RefCounted

var coord: Vector2i = Coord.NONE
var world_id: String = ""
var owner_id: int = 0
var name: String = ""
var biome: Biome.Type = Biome.Type.TEMPERATE
## true, gdy JSON zawiera resources (osada własna); cudze osady mają tylko dane publiczne.
var is_own: bool = false
var resources: Dictionary = ResourceTypes.empty()
var production_per_hour: Dictionary = ResourceTypes.empty()
var capacity: float = 0.0
var population: int = 0
var population_max: int = 0
## Buildings.Type -> poziom. Brak klucza = poziom 0.
var buildings: Dictionary = {}
var last_sync_at: float = 0.0


## Zwraca null, gdy brakuje x/y. `biome` podaje GameState z WorldGrid; decyduje o dozwolonych budynkach.
static func from_json(d: Dictionary, biome_type: Biome.Type) -> Settlement:
	var coord := Coord.from_json(d)
	if coord == Coord.NONE:
		push_warning("Settlement: rekord bez x/y odrzucony")
		return null
	var s := Settlement.new()
	s.coord = coord
	s.world_id = str(d.get("world", ""))
	s.owner_id = int(d.get("ownerId", 0))
	s.name = str(d.get("name", ""))
	s.biome = biome_type
	s.is_own = d.has("resources")
	if s.is_own:
		s.resources = ResourceTypes.normalize(d.get("resources"))
		s.production_per_hour = ResourceTypes.normalize(d.get("productionPerHour"))
		_warn_production_foreign_to_biome(s.production_per_hour, biome_type, coord)
		s.capacity = float(d.get("capacity", 0.0))
		s.population = int(d.get("population", 0))
		s.population_max = int(d.get("populationMax", 0))
		s.last_sync_at = TimeUtil.parse_iso8601(str(d.get("lastSyncAt", "1970-01-01T00:00:00Z")))
		s.buildings = _parse_buildings(d.get("buildings", {}), biome_type)
	return s


## Serwer podaje produkcję wprost (klient jej nie wylicza), więc niezgodną wartość tylko
## zgłaszamy ostrzeżeniem, tak jak `_parse_buildings` robi to dla budynków; wartość zostaje.
static func _warn_production_foreign_to_biome(production: Dictionary, biome_type: Biome.Type, coord: Vector2i) -> void:
	var allowed := Biome.resources(biome_type)
	for k in production.keys():
		if float(production[k]) > 0.0 and not allowed.has(k):
			push_warning(
				"Settlement: produkcja '%s' niezgodna z biomem %s na %s, wartość zachowana"
				% [k, Biome.key(biome_type), Coord.key(coord)]
			)


static func _parse_buildings(raw: Variant, biome_type: Biome.Type) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	var allowed := Biome.slots(biome_type)
	for k in raw.keys():
		var t := Buildings.from_key(str(k))
		if t < 0 or not allowed.has(t):
			push_warning("Settlement: budynek '%s' niedozwolony w biomie %s, ignoruję" % [k, Biome.key(biome_type)])
			continue
		out[t] = int(raw[k])
	return out


## Lazy-eval: stored + rate * hours, obcięte do [0, capacity]. `now` zawsze jako argument.
func current_resources(now: float) -> Dictionary:
	var hours := maxf(now - last_sync_at, 0.0) / 3600.0
	var out := {}
	for k in ResourceTypes.ALL:
		var v: float = resources[k] + production_per_hour[k] * hours
		out[k] = clampf(v, 0.0, capacity)
	return out


func level(t: Buildings.Type) -> int:
	return int(buildings.get(t, 0))


func produces(resource: String) -> bool:
	return production_per_hour.get(resource, 0.0) > 0.0
