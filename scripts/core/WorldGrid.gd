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


## Deterministyczny, 31-bitowy hash komórki; identyczny algorytm ma mieć backend.
static func hash_cell(world_seed: int, cell: Vector2i) -> int:
	var h: int = world_seed & 0x7fffffff
	h = (h * 31 + cell.x + 1000003) & 0x7fffffff
	h = (h * 31 + cell.y + 1000033) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h


static func hash01(h: int) -> float:
	return float(h % 10007) / 10007.0


## Wartość siatki w punkcie całkowitym (ix, iy), w [-1, 1). Część kontraktu geografii -
## patrz sekcja 4.3 api-guidelines.md; backend musi liczyć identycznie na IEEE 754 binary64.
static func _lattice(seed_value: int, ix: int, iy: int) -> float:
	return hash01(hash_cell(seed_value, Vector2i(ix, iy))) * 2.0 - 1.0


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Dwuwymiarowy szum wartościowy (bilinearna interpolacja rogów siatki wygładzona `_smooth`).
## Zastępuje `FastNoiseLite`/OpenSimplex2S - patrz ADR 0001, sekcja "Zmiana implementacji szumu".
static func _value_noise(seed_value: int, x: float, y: float) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	var u := _smooth(fx)
	var v := _smooth(fy)
	var n00 := _lattice(seed_value, ix, iy)
	var n10 := _lattice(seed_value, ix + 1, iy)
	var n01 := _lattice(seed_value, ix, iy + 1)
	var n11 := _lattice(seed_value, ix + 1, iy + 1)
	var a := n00 + (n10 - n00) * u
	var b := n01 + (n11 - n01) * u
	return a + (b - a) * v


## Fraktalna suma `_value_noise` przez `octaves` oktaw; sól oktawy `1013` i mnożniki `0.5`/`2.0`
## amplitudy i częstotliwości są częścią kontraktu (api-guidelines.md sekcja 4.3).
static func fbm(seed_value: int, x: float, y: float, octaves: int) -> float:
	var total := 0.0
	var norm := 0.0
	var amp := 1.0
	var freq := 1.0
	for i in octaves:
		total += amp * _value_noise(seed_value + i * 1013, x * freq, y * freq)
		norm += amp
		amp *= 0.5
		freq *= 2.0
	return total / norm


## Wyspa w komórce albo null, gdy komórka jest morzem.
static func island_at(world_seed: int, cell: Vector2i) -> Island:
	var land := fbm(world_seed, float(cell.x) * LAND_FREQUENCY, float(cell.y) * LAND_FREQUENCY, 2)
	if land <= LAND_THRESHOLD:
		return null
	var h := hash_cell(world_seed, cell)
	var island := Island.new()
	island.coord = cell
	island.seed_val = h
	var b: float = fbm(world_seed + 1, float(cell.x) * BIOME_FREQUENCY, float(cell.y) * BIOME_FREQUENCY, 1)
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
