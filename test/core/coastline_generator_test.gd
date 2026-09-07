extends GdUnitTestSuite


func test_deterministic_for_same_seed() -> void:
	assert_that(CoastlineGenerator.generate(84920, 100.0)).is_equal(CoastlineGenerator.generate(84920, 100.0))


func test_different_seeds_differ() -> void:
	assert_that(CoastlineGenerator.generate(1, 100.0)).is_not_equal(CoastlineGenerator.generate(2, 100.0))


func test_point_count() -> void:
	assert_int(CoastlineGenerator.generate(7, 100.0, 32).size()).is_equal(32)


func test_radii_within_bounds() -> void:
	var radius := 100.0
	var roughness := 0.35
	for seed_val in [1, 42, 84920, 1337]:
		var pts := CoastlineGenerator.generate(seed_val, radius, 48, roughness)
		for p in pts:
			assert_float(p.length()).is_between(radius * (1.0 - roughness) * CoastlineGenerator.ELLIPSE_MIN, radius * (1.0 + roughness) * CoastlineGenerator.ELLIPSE_MAX)


func test_polygon_is_triangulable() -> void:
	for seed_val in [1, 42, 84920, 1337, 99999]:
		var pts := CoastlineGenerator.generate(seed_val, 100.0, 48, 0.4)
		assert_int(Geometry2D.triangulate_polygon(pts).size()).is_greater(0)


func test_scaled_multiplies_points() -> void:
	var pts := PackedVector2Array([Vector2(1, 2), Vector2(-3, 4)])
	assert_that(CoastlineGenerator.scaled(pts, 2.0)).is_equal(PackedVector2Array([Vector2(2, 4), Vector2(-6, 8)]))


func test_bay_angle_points_to_closest_point() -> void:
	var pts := PackedVector2Array([Vector2(100, 0), Vector2(0, 50), Vector2(-100, 0), Vector2(0, -100)])
	assert_float(CoastlineGenerator.bay_angle(pts)).is_equal_approx(PI / 2.0, 0.001)
