extends SceneTree

## Generuje `contract/world-parity.json` - referencyjny zrzut geografii `WorldGrid`, którym
## backend NestJS sprawdza zgodność swojej implementacji bit-w-bit (ADR 0001,
## api-guidelines.md sekcja 4.5 "Jak udowodnić zgodność"). Użycie: ./run_parity.sh
## (patrz też run_tests.sh, run_smoke.sh).
##
## Floaty serializujemy ręcznie przez String.num(v, 17), NIGDY przez JSON.stringify(): domyślne
## formatowanie floatów w JSON.stringify() zaokrągla precyzję i ukrywa dokładnie ten dryf między
## klientem a backendem, który ten plik ma wykrywać.

const GRID_SIZE := 200
const SEEDS: Array[int] = [1337, 99999]
const OUT_PATH := "res://contract/world-parity.json"


func _init() -> void:
	var out := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if out == null:
		push_error("world_parity_dump: nie można otworzyć %s do zapisu" % OUT_PATH)
		quit(1)
		return
	out.store_string(_build_json())
	out.close()
	print(
		"world_parity_dump: zapisano %s (%d seedów, %dx%d komórek)"
		% [OUT_PATH, SEEDS.size(), GRID_SIZE, GRID_SIZE]
	)
	quit(0)


func _num(v: float) -> String:
	return String.num(v, 17)


func _deposit_json(deposit: Dictionary) -> String:
	var parts: Array[String] = []
	for r in deposit:
		parts.append("\"%s\":%s" % [r, _num(deposit[r])])
	return "{%s}" % ",".join(parts)


## Land/biome liczone niezależnie od `island_at`, żeby zapisać je też dla komórek morza -
## `island_at` zwraca null dla morza i nie ujawnia surowych wartości szumu.
func _cell_json(world_seed: int, x: int, y: int) -> String:
	var cell := Vector2i(x, y)
	var land := WorldGrid.fbm(
		world_seed, float(x) * WorldGrid.LAND_FREQUENCY, float(y) * WorldGrid.LAND_FREQUENCY, 2
	)
	var biome := WorldGrid.fbm(
		world_seed + 1, float(x) * WorldGrid.BIOME_FREQUENCY, float(y) * WorldGrid.BIOME_FREQUENCY, 1
	)
	var island := WorldGrid.island_at(world_seed, cell)
	var fields: Array[String] = [
		"\"x\":%d" % x,
		"\"y\":%d" % y,
		"\"hash\":%d" % WorldGrid.hash_cell(world_seed, cell),
		"\"land\":%s" % _num(land),
		"\"biome\":%s" % _num(biome),
		"\"isIsland\":%s" % ("true" if island != null else "false"),
	]
	if island != null:
		fields.append("\"biomeType\":\"%s\"" % Biome.key(island.biome))
		fields.append("\"radius\":%s" % _num(island.radius))
		fields.append("\"deposit\":%s" % _deposit_json(island.deposit))
	return "{%s}" % ",".join(fields)


func _world_json(world_seed: int) -> String:
	var cells: Array[String] = []
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			cells.append(_cell_json(world_seed, x, y))
	return "{\"seed\":%d,\"cells\":[%s]}" % [world_seed, ",".join(cells)]


func _constants_json() -> String:
	var resources: Array[String] = []
	for r in ResourceTypes.ALL:
		resources.append("\"%s\"" % r)
	var out := "{"
	out += "\"landFrequency\":%s," % _num(WorldGrid.LAND_FREQUENCY)
	out += "\"biomeFrequency\":%s," % _num(WorldGrid.BIOME_FREQUENCY)
	out += "\"biomeBand\":%s," % _num(WorldGrid.BIOME_BAND)
	out += "\"landThreshold\":%s," % _num(WorldGrid.LAND_THRESHOLD)
	out += "\"radiusMin\":%s," % _num(WorldGrid.RADIUS_MIN)
	out += "\"radiusMax\":%s," % _num(WorldGrid.RADIUS_MAX)
	out += "\"depositChance\":%s," % _num(WorldGrid.DEPOSIT_CHANCE)
	out += "\"resourceOrder\":[%s]" % ",".join(resources)
	out += "}"
	return out


func _build_json() -> String:
	var worlds: Array[String] = []
	for s in SEEDS:
		worlds.append(_world_json(s))
	return (
		"{\"gridSize\":%d,\"constants\":%s,\"worlds\":[%s]}\n"
		% [GRID_SIZE, _constants_json(), ",".join(worlds)]
	)
