class_name MockProvider
extends ApiProvider

const WORLD_PATH := "res://fixtures/world.json"
const SETTLEMENTS_PATH := "res://fixtures/settlements.json"
const FLEETS_PATH := "res://fixtures/fleets.json"

## Zegar wstrzykiwany w testach; domyślnie TimeUtil.now.
var clock: Callable = TimeUtil.now
var _settlements: Array = []
var _fleets: Array = []


static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("MockProvider: nie mogę odczytać %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("MockProvider: niepoprawny JSON w %s" % path)
	return parsed


func fetch_world() -> Variant:
	var d: Variant = load_json(WORLD_PATH)
	if not (d is Dictionary):
		return null
	d["serverTime"] = TimeUtil.to_iso8601(clock.call())
	return d


## Pierwsze wywołanie stempluje lastSyncAt = now; kolejne przeliczają zasoby jak prawdziwy serwer.
func fetch_settlements() -> Variant:
	var now: float = clock.call()
	if _settlements.is_empty():
		var arr: Variant = load_json(SETTLEMENTS_PATH)
		if not (arr is Array):
			return null
		_settlements = arr
		for d in _settlements:
			if d is Dictionary and d.has("resources"):
				d["lastSyncAt"] = TimeUtil.to_iso8601(now)
	else:
		for d in _settlements:
			if d is Dictionary and d.has("resources"):
				advance(d, now)
	return _settlements.duplicate(true)


## Fixture podaje departOffsetMin / arriveOffsetMin względem pierwszego załadowania.
func fetch_fleets() -> Variant:
	if _fleets.is_empty():
		var now: float = clock.call()
		var arr: Variant = load_json(FLEETS_PATH)
		if not (arr is Array):
			return null
		_fleets = arr
		for d in _fleets:
			if d is Dictionary:
				d["departAt"] = TimeUtil.to_iso8601(now + float(d.get("departOffsetMin", 0)) * 60.0)
				d["arriveAt"] = TimeUtil.to_iso8601(now + float(d.get("arriveOffsetMin", 0)) * 60.0)
				d.erase("departOffsetMin")
				d.erase("arriveOffsetMin")
	return _fleets.duplicate(true)


## Symuluje serwer: resources += production * hours (do capacity), lastSyncAt = now.
static func advance(d: Dictionary, now: float) -> void:
	var last := TimeUtil.parse_iso8601(str(d.get("lastSyncAt", TimeUtil.to_iso8601(now))))
	var hours := maxf(now - last, 0.0) / 3600.0
	var res := ResourceTypes.normalize(d.get("resources"))
	var prod := ResourceTypes.normalize(d.get("productionPerHour"))
	var cap := float(d.get("capacity", 0.0))
	for k in ResourceTypes.ALL:
		res[k] = clampf(res[k] + prod[k] * hours, 0.0, cap)
	d["resources"] = res
	d["lastSyncAt"] = TimeUtil.to_iso8601(now)
