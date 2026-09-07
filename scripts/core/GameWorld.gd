class_name GameWorld
extends RefCounted

var id: String = ""
var seed_val: int = 0
var size: Vector2i = Vector2i(200, 200)
var wind: Vector2 = Vector2.ZERO
var status: String = "OPEN"
var player_id: int = 0
var home_settlement: Vector2i = Coord.NONE
var server_time: float = 0.0


static func from_json(d: Dictionary) -> GameWorld:
	var w := GameWorld.new()
	w.id = str(d.get("id", ""))
	w.seed_val = int(d.get("seed", 0))
	var sz: Variant = d.get("size", {})
	if sz is Dictionary:
		w.size = Vector2i(int(sz.get("w", 200)), int(sz.get("h", 200)))
	var wind: Variant = d.get("wind", {})
	if wind is Dictionary:
		w.wind = Vector2(float(wind.get("x", 0.0)), float(wind.get("y", 0.0)))
	w.status = str(d.get("status", "OPEN"))
	w.player_id = int(d.get("playerId", 0))
	w.home_settlement = Coord.from_json(d.get("homeSettlement"))
	if d.has("serverTime"):
		w.server_time = TimeUtil.parse_iso8601(str(d["serverTime"]))
	return w


func in_bounds(cell: Vector2i) -> bool:
	return WorldGrid.in_bounds(cell, size)
