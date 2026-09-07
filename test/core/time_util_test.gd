extends GdUnitTestSuite

const UNIX_2026_09_07_12 := 1788782400.0


func test_parse_iso8601_with_z() -> void:
	assert_float(TimeUtil.parse_iso8601("2026-09-07T12:00:00Z")).is_equal(UNIX_2026_09_07_12)


func test_parse_iso8601_with_offset() -> void:
	assert_float(TimeUtil.parse_iso8601("2026-09-07T14:00:00+02:00")).is_equal(UNIX_2026_09_07_12)
	assert_float(TimeUtil.parse_iso8601("2026-09-07T10:00:00-02:00")).is_equal(UNIX_2026_09_07_12)


func test_parse_iso8601_with_milliseconds() -> void:
	assert_float(TimeUtil.parse_iso8601("2026-09-07T12:00:00.123Z")).is_equal(UNIX_2026_09_07_12)


func test_to_iso8601_roundtrip() -> void:
	assert_str(TimeUtil.to_iso8601(UNIX_2026_09_07_12)).is_equal("2026-09-07T12:00:00Z")
	assert_float(TimeUtil.parse_iso8601(TimeUtil.to_iso8601(UNIX_2026_09_07_12))).is_equal(UNIX_2026_09_07_12)


func test_format_amount() -> void:
	assert_str(TimeUtil.format_amount(950.0)).is_equal("950")
	assert_str(TimeUtil.format_amount(1234.0)).is_equal("1.2k")
	assert_str(TimeUtil.format_amount(1500000.0)).is_equal("1.5M")


func test_format_countdown() -> void:
	assert_str(TimeUtil.format_countdown(125.0)).is_equal("02:05")
	assert_str(TimeUtil.format_countdown(-5.0)).is_equal("00:00")


func test_set_server_time_shifts_now() -> void:
	var before := TimeUtil.now()
	TimeUtil.set_server_time(before + 3600.0)
	assert_float(TimeUtil.now()).is_greater(before + 3599.0)
	TimeUtil.server_time_offset = 0.0
