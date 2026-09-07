extends GdUnitTestSuite


func test_key_roundtrip() -> void:
	var c := Vector2i(10, 15)
	assert_str(Coord.key(c)).is_equal("10:15")
	assert_that(Coord.from_key(Coord.key(c))).is_equal(c)


func test_from_json() -> void:
	assert_that(Coord.from_json({"x": 3, "y": 4})).is_equal(Vector2i(3, 4))
	assert_that(Coord.from_json({"x": 3})).is_equal(Coord.NONE)
	assert_that(Coord.from_json(null)).is_equal(Coord.NONE)


func test_from_key_invalid() -> void:
	assert_that(Coord.from_key("garbage")).is_equal(Coord.NONE)
	assert_that(Coord.from_key("a:b")).is_equal(Coord.NONE)
	assert_that(Coord.from_key("1:b")).is_equal(Coord.NONE)
	assert_that(Coord.from_key("a:1")).is_equal(Coord.NONE)
	assert_that(Coord.from_key("1:2:3")).is_equal(Coord.NONE)
