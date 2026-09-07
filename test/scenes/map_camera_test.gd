extends GdUnitTestSuite


func _camera() -> MapCamera:
	var cam: MapCamera = auto_free(MapCamera.new())
	add_child(cam)
	return cam


func test_screen_to_world_at_center_is_camera_position() -> void:
	var cam := _camera()
	cam.position = Vector2(1000, 2000)
	var center := cam.get_viewport_rect().size / 2.0
	assert_that(cam.screen_to_world(center)).is_equal(Vector2(1000, 2000))


func test_zoom_is_clamped() -> void:
	var cam := _camera()
	cam._zoom_at(Vector2.ZERO, 100.0)
	assert_float(cam.zoom.x).is_equal(MapCamera.ZOOM_MAX)
	cam._zoom_at(Vector2.ZERO, 0.0001)
	assert_float(cam.zoom.x).is_equal(MapCamera.ZOOM_MIN)


func test_zoom_keeps_point_under_cursor() -> void:
	var cam := _camera()
	cam.position = Vector2(500, 500)
	var screen := Vector2(100, 100)
	var before := cam.screen_to_world(screen)
	cam._zoom_at(screen, 1.5)
	assert_that(cam.screen_to_world(screen)).is_equal_approx(before, Vector2(0.01, 0.01))


func test_bounds_clamp_position() -> void:
	var cam := _camera()
	cam.set_bounds(Rect2(0, 0, 10000, 10000))
	cam.position = Vector2(-5000, 20000)
	cam._clamp_position()
	var half := cam.get_viewport_rect().size / cam.zoom / 2.0
	assert_that(cam.position).is_equal(Vector2(half.x, 10000 - half.y))


func test_small_world_is_centered() -> void:
	var cam := _camera()
	cam.set_bounds(Rect2(0, 0, 100, 100))
	cam.position = Vector2(9999, 9999)
	cam._clamp_position()
	assert_that(cam.position).is_equal(Vector2(50, 50))
