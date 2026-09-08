class_name WorldGrid
extends RefCounted

const CELL_SIZE := 256.0
const CHUNK_SIZE := 8
const LAND_FREQUENCY := 0.12
const LAND_THRESHOLD := 0.30
const BIOME_FREQUENCY := 0.03
const BIOME_BAND := 0.15
const DEPOSIT_CHANCE := 0.3
const RADIUS_MIN := 60.0
const RADIUS_MAX := 110.0

static var _noise_cache: Dictionary = {}


static func _noises(world_seed: int) -> Array:
	if not _noise_cache.has(world_seed):
		var land := FastNoiseLite.new()
		land.seed = world_seed
		land.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		land.fractal_octaves = 2
		land.frequency = LAND_FREQUENCY
		var biome := FastNoiseLite.new()
		biome.seed = world_seed + 1
		biome.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		biome.fractal_octaves = 1
		biome.frequency = BIOME_FREQUENCY
		_noise_cache[world_seed] = [land, biome]
	return _noise_cache[world_seed]


## Deterministyczny, 31-bitowy hash komórki; identyczny algorytm ma mieć backend.
static func hash_cell(world_seed: int, cell: Vector2i) -> int:
	var h: int = world_seed & 0x7fffffff
	h = (h * 31 + cell.x + 1000003) & 0x7fffffff
	h = (h * 31 + cell.y + 1000033) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h


static func hash01(h: int) -> float:
	return float(h % 10007) / 10007.0


## Wyspa w komórce albo null, gdy komórka jest morzem.
static func island_at(world_seed: int, cell: Vector2i) -> Island:
	var noises := _noises(world_seed)
	if noises[0].get_noise_2d(cell.x, cell.y) <= LAND_THRESHOLD:
		return null
	var h := hash_cell(world_seed, cell)
	var island := Island.new()
	island.coord = cell
	island.seed_val = h
	var b: float = noises[1].get_noise_2d(cell.x, cell.y)
	if b < -BIOME_BAND:
		island.biome = Biome.Type.TROPICAL
	elif b > BIOME_BAND:
		island.biome = Biome.Type.VOLCANIC
	else:
		island.biome = Biome.Type.TEMPERATE
	island.radius = RADIUS_MIN + (RADIUS_MAX - RADIUS_MIN) * hash01(h)
	island.deposit = _deposit_for(island.biome, h)
	return island


## Znalezisko zawiera 1-2 zasoby SPOZA biomu wyspy (ADR 0002).
static func _deposit_for(biome: Biome.Type, h: int) -> Dictionary:
	var h2 := hash_cell(h, Vector2i(7, 11))
	if hash01(h2) >= DEPOSIT_CHANCE:
		return {}
	var foreign: Array[String] = []
	for r in ResourceTypes.ALL:
		if not Biome.resources(biome).has(r):
			foreign.append(r)
	var h3 := hash_cell(h2, Vector2i(3, 5))
	var count := 1 + int(hash01(h3) * 2.0)
	var start := int(hash01(hash_cell(h3, Vector2i(1, 1))) * foreign.size())
	var out := {}
	for i in count:
		var r: String = foreign[(start + i) % foreign.size()]
		var h4 := hash_cell(h3, Vector2i(i + 1, 0))
		out[r] = float(200 + int(hash01(h4) * 800.0))
	return out


static func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / CELL_SIZE).floor())


static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / CHUNK_SIZE),
		floori(float(cell.y) / CHUNK_SIZE)
	)


static func in_bounds(cell: Vector2i, size: Vector2i) -> bool:
	return (
		cell.x >= 0 and cell.y >= 0 and
		cell.x < size.x and cell.y < size.y
	)
