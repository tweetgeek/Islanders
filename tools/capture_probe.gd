extends Node

## Sonda wizualna: zapisuje obraz viewportu 1:1 do plików PNG i mierzy geometrię paska.
## Nie jest testem i niczego nie sprawdza - dostarcza dowodów do oceny wyglądu przez człowieka.
##
## Powstała, bo zrzut z systemu operacyjnego bywa przeskalowany i zmiękcza obraz, co fałszuje
## ocenę ostrości. Przy uruchomieniu z rozdzielczością równą viewportowi zapis z viewportu jest
## wolny od przepróbkowania. Przy okazji pokazała usterkę, której nie widział żaden test:
## etykieta może mieć poprawny tekst i zerową szerokość na ekranie.
##
## Użycie:
##   Godot --path . --resolution 1080x1920 res://tools/Capture.tscn -- <katalog_wyjściowy>

const MAIN := preload("res://scenes/views/Main.tscn")

## Wycinki zapisywane dodatkowo w skali 1:1, żeby dało się ocenić szczegół bez skalowania.
## Klucz to nazwa pliku, wartość to prostokąt w pikselach canvasu.
const CROPS := {
	"pasek": Rect2i(0, 0, 1080, 320),
	"status-osady": Rect2i(0, 1600, 1080, 320),
}

var _out_dir := ""
var _frame := 0
var _shots := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else "user://"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	add_child(MAIN.instantiate())
	print("CAPTURE out=%s viewport=%s window=%s" % [
		_out_dir, get_viewport().get_visible_rect().size, DisplayServer.window_get_size()
	])


## Kolejne klatki to harmonogram: każdy stan potrzebuje czasu na ułożenie i animacje,
## zanim ma sens go fotografować.
func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		40:
			_report_bar()
			_report_labels(get_tree().get_first_node_in_group("hud"))
			_save("01-osada")
		42:
			var sheets := get_tree().get_first_node_in_group("sheets")
			sheets.open_building(GameState.active_settlement, Buildings.Type.TOWN_HALL)
		70:
			_save("02-arkusz-budynku")
		72:
			get_tree().get_first_node_in_group("sheets").close()
		100:
			SceneManager.show_world_map()
		140:
			_save("03-mapa")
		145:
			print("CAPTURE DONE shots=%d" % _shots)
			get_tree().quit(0)


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out_dir, tag])
	print("SHOT %s/%s.png %dx%d" % [_out_dir, tag, img.get_width(), img.get_height()])
	for crop_name in CROPS:
		var region: Rect2i = (CROPS[crop_name] as Rect2i).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if region.size.x <= 0 or region.size.y <= 0:
			continue
		var cropped := img.get_region(region)
		cropped.save_png("%s/%s--%s.png" % [_out_dir, tag, crop_name])
		print("CROP %s--%s %dx%d" % [tag, crop_name, cropped.get_width(), cropped.get_height()])
	_shots += 1


## Wysokość paska w procentach ekranu: liczba, o którą najłatwiej się spierać na oko.
func _report_bar() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var screen_height := get_viewport().get_visible_rect().size.y
	print("MEASURE bar_height=%.1f (%.1f%% ekranu %d)" % [
		hud.bar_height(), 100.0 * hud.bar_height() / screen_height, int(screen_height)
	])


## Każda etykieta z tekstem kontra szerokość, jakiej ten tekst potrzebuje w swoim foncie.
## Etykieta węższa niż własny tekst jest niewidoczna dla gracza, choć jej `text` jest poprawny.
func _report_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label and not (child as Label).text.is_empty():
			var label := child as Label
			var needed: float = label.get_theme_font("font").get_string_size(
				label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
			).x
			print("LABEL %-18s szerokość=%7.1f potrzebuje=%7.1f %s tekst=%s" % [
				label.name, label.size.x, needed,
				"ok" if label.size.x >= needed else "ZA WĄSKA", JSON.stringify(label.text)
			])
		_report_labels(child)
