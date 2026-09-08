extends Node

@onready var view_container: Node = $ViewContainer
@onready var sea: ColorRect = $SeaBackground/Sea


func _ready() -> void:
	MedievalTheme.install()
	sea.color = MedievalTheme.SEA
	SceneManager.register_container(view_container)
	GameState.state_loaded.connect(SceneManager.show_world_map, CONNECT_ONE_SHOT)
	ApiClient.request_failed.connect(func(reason: String) -> void: push_error("Ładowanie nieudane: %s" % reason))
	ApiClient.load_initial()
