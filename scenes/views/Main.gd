extends Node

@onready var view_container: Node = $ViewContainer
@onready var sea: ColorRect = $SeaBackground/Sea
@onready var sheets: CanvasLayer = $Sheets


func _ready() -> void:
	MedievalTheme.install()
	sea.color = MedievalTheme.SEA
	SceneManager.register_container(view_container)
	GameState.state_loaded.connect(SceneManager.show_island_detail, CONNECT_ONE_SHOT)
	ApiClient.request_failed.connect(func(reason: String) -> void: push_error("Ładowanie nieudane: %s" % reason))
	sheets.upgrade_requested.connect(func(coord: Vector2i, building: int) -> void:
		print("upgrade_requested: %s w %s" % [Buildings.key(building), Coord.key(coord)])
	)
	ApiClient.load_initial()
