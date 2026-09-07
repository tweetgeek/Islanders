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
	var w: Variant = await provider.fetch_world()
	if w == null:
		request_failed.emit("world")
		return
	var world_dict: Dictionary = w
	if world_dict.has("serverTime"):
		TimeUtil.set_server_time(TimeUtil.parse_iso8601(str(world_dict["serverTime"])))
	GameState.apply_world(world_dict)
	var settlements: Variant = await provider.fetch_settlements()
	if settlements == null:
		request_failed.emit("settlements")
		return
	GameState.apply_settlements(settlements)
	var fleets: Variant = await provider.fetch_fleets()
	if fleets == null:
		request_failed.emit("fleets")
		return
	GameState.apply_fleets(fleets)
	GameState.finish_loading()
	_timer.start()


func resync() -> void:
	var settlements: Variant = await provider.fetch_settlements()
	if settlements == null:
		request_failed.emit("settlements")
		return
	GameState.apply_settlements(settlements)
	var fleets: Variant = await provider.fetch_fleets()
	if fleets == null:
		request_failed.emit("fleets")
		return
	GameState.apply_fleets(fleets)
	synced.emit()
