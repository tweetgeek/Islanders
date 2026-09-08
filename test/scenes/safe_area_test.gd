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
