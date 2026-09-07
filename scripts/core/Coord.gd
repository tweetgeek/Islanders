class_name Coord
extends RefCounted

## Wartość "brak współrzędnych"; świat zaczyna się od (0, 0), więc (-1, -1) nigdy nie jest komórką.
const NONE := Vector2i(-1, -1)


static func key(c: Vector2i) -> String:
	return "%d:%d" % [c.x, c.y]


static func from_key(k: String) -> Vector2i:
	var parts := k.split(":")
	if parts.size() != 2:
		return NONE
	return Vector2i(int(parts[0]), int(parts[1]))


## {"x": 10, "y": 15} -> Vector2i(10, 15); brak pola -> NONE
static func from_json(d: Variant) -> Vector2i:
	if not (d is Dictionary) or not d.has("x") or not d.has("y"):
		return NONE
	return Vector2i(int(d["x"]), int(d["y"]))


static func to_json(c: Vector2i) -> Dictionary:
	return {"x": c.x, "y": c.y}
