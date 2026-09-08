extends GdUnitTestSuite


func test_framework_runs() -> void:
	assert_int(1 + 1).is_equal(2)


func test_noise_is_deterministic() -> void:
	var n := FastNoiseLite.new()
	n.seed = 42
	assert_float(n.get_noise_2d(1.0, 2.0)).is_equal(n.get_noise_2d(1.0, 2.0))
