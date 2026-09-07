extends Node

signal request_failed(reason: String)
signal synced

const RESYNC_SECONDS := 60.0

var provider: ApiProvider
var _timer: Timer


func _ready() -> void:
	var use_mock: bool = ProjectSettings.get_setting("islanders/api/use_mock", true)
	if use_mock:
		provider = MockProvider.new()
	else:
		var url: String = ProjectSettings.get_setting("islanders/api/base_url", "http://localhost:3000")
		provider = HttpProvider.new(self, url)
	_timer = Timer.new()
	_timer.wait_time = RESYNC_SECONDS
	_timer.timeout.connect(resync)
	add_child(_timer)


func load_initial() -> void:
	var w: Dictionary = await provider.fetch_world()
	if w.is_empty():
		request_failed.emit("world")
		return
	if w.has("serverTime"):
		TimeUtil.set_server_time(TimeUtil.parse_iso8601(str(w["serverTime"])))
	GameState.apply_world(w)
	GameState.apply_settlements(await provider.fetch_settlements())
	GameState.apply_fleets(await provider.fetch_fleets())
	GameState.finish_loading()
	_timer.start()


func resync() -> void:
	var settlements: Array = await provider.fetch_settlements()
	GameState.apply_settlements(settlements)
	GameState.apply_fleets(await provider.fetch_fleets())
	synced.emit()
