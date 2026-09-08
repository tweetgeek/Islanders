class_name CoastlineGenerator
extends RefCounted

const NOISE_SCALE := 2.0
const ELLIPSE_MIN := 0.8
const ELLIPSE_MAX := 1.2


## Miesza surowy seed (jeszcze niehashowany) i rzutuje na [0, 1). Prywatne dla tego pliku;
## to NIE jest `WorldGrid.hash01`, który zamienia na [0, 1) liczbę już wcześniej zhashowaną.
static func _mix_seed01(seed_val: int) -> float:
	var h: int = (seed_val ^ (seed_val >> 16)) * 0x45d9f3b
	h = (h ^ (h >> 16)) & 0x7fffffff
	return float(h % 10007) / 10007.0


static func ellipse_factor(seed_val: int) -> float:
	return ELLIPSE_MIN + (ELLIPSE_MAX - ELLIPSE_MIN) * _mix_seed01(seed_val)


## Zamknięty kontur wyspy: punkty na okręgu o promieniu zaburzonym szumem.
static func generate(seed_val: int, radius: float, points: int = 48, roughness: float = 0.35) -> PackedVector2Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	noise.frequency = 1.0
	var ellipse := ellipse_factor(seed_val)
	var out := PackedVector2Array()
	out.resize(points)
	for i in points:
		var t := float(i) / float(points) * TAU
		var n := noise.get_noise_2d(cos(t) * NOISE_SCALE, sin(t) * NOISE_SCALE)
		var r := radius * (1.0 + roughness * n)
		out[i] = Vector2(cos(t) * r, sin(t) * r * ellipse)
	return out


static func scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = points[i] * factor
	return out


## Kąt (rad) punktu konturu najbliższego środka: tam leży "zatoka" na stocznię.
static func bay_angle(points: PackedVector2Array) -> float:
	var best := 0
	for i in points.size():
		if points[i].length() < points[best].length():
			best = i
	return points[best].angle()
