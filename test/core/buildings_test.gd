extends GdUnitTestSuite


func test_every_building_has_icon_and_description() -> void:
	for t in Buildings.Type.values():
		assert_bool(Buildings.DESCRIPTIONS.has(t)).override_failure_message("brak opisu %s" % Buildings.key(t)).is_true()
		assert_str(String(Buildings.icon(t))).is_not_empty()


func test_extraction_buildings_use_resource_icon() -> void:
	assert_str(String(Buildings.icon(Buildings.Type.SAWMILL))).is_equal("wood")
	assert_str(String(Buildings.icon(Buildings.Type.SULFUR_PIT))).is_equal("sulfur")
	assert_str(String(Buildings.icon(Buildings.Type.TOWN_HALL))).is_equal("town_hall")


func test_every_resource_has_icon() -> void:
	for r in ResourceTypes.ALL:
		assert_bool(ResourceTypes.ICONS.has(r)).is_true()
