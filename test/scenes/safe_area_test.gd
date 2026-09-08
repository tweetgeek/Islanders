extends GdUnitTestSuite


## Pod headless safe area = całe okno, więc oba offsety są zerem; test pilnuje kontraktu
## (nieujemne, w pikselach canvasu) i tego, że funkcje w ogóle da się wołać bez sceny.
func test_insets_are_non_negative() -> void:
	assert_float(SafeArea.top_inset(get_viewport())).is_greater_equal(0.0)
	assert_float(SafeArea.bottom_inset(get_viewport())).is_greater_equal(0.0)


func test_scale_converts_window_pixels_to_canvas_pixels() -> void:
	var vis := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	assert_float(SafeArea.scale_for(get_viewport())).is_equal_approx(vis.y / maxf(win.y, 1.0), 0.0001)


func test_insets_for_converts_window_pixels_to_canvas_pixels() -> void:
	# Okno 1080x2000 z notchem 100 px u góry i paskiem 100 px u dołu, canvas 1080x1920.
	var insets := SafeArea.insets_for(Rect2i(0, 100, 1080, 1800), Vector2i(1080, 2000), Vector2(1080, 1920))
	assert_float(insets.x).is_equal_approx(96.0, 0.001)
	assert_float(insets.y).is_equal_approx(96.0, 0.001)


func test_insets_for_distinguishes_top_from_bottom() -> void:
	# Asymetryczne wstawki: notch 200 px, brak paska u dołu. Wersja czytająca dwa razy
	# tę samą krawędź zwróciłaby tu dwie równe wartości.
	var insets := SafeArea.insets_for(Rect2i(0, 200, 1080, 1800), Vector2i(1080, 2000), Vector2(1080, 2000))
	assert_float(insets.x).is_equal_approx(200.0, 0.001)
	assert_float(insets.y).is_equal_approx(0.0, 0.001)


func test_insets_for_clamps_degenerate_geometry() -> void:
	# Bezpieczny obszar większy niż okno i okno o zerowej wysokości nie mogą dać ujemnych
	# wstawek ani dzielenia przez zero.
	var bigger := SafeArea.insets_for(Rect2i(0, -50, 1080, 2200), Vector2i(1080, 2000), Vector2(1080, 2000))
	assert_float(bigger.x).is_equal(0.0)
	assert_float(bigger.y).is_equal(0.0)
	var zero_window := SafeArea.insets_for(Rect2i(0, 0, 0, 0), Vector2i(0, 0), Vector2(1080, 1920))
	assert_float(zero_window.x).is_equal(0.0)
	assert_float(zero_window.y).is_equal(0.0)
