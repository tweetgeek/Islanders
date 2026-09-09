extends GdUnitTestSuite


func test_px_scales_and_rounds() -> void:
	assert_int(MedievalTheme.px(10.0)).is_equal(28)
	assert_int(MedievalTheme.px(0.0)).is_equal(0)
	assert_float(MedievalTheme.SCALE).is_greater(0.0)


func test_build_has_every_variation() -> void:
	var t := MedievalTheme.build()
	assert_object(t).is_not_null()
	assert_object(t.default_font).is_not_null()
	for name: StringName in MedievalTheme.VARIATIONS:
		assert_str(String(t.get_type_variation_base(name))) \
			.override_failure_message("brak wariacji %s" % name) \
			.is_equal(String(MedievalTheme.VARIATIONS[name]))


func test_flat_scales_paddings() -> void:
	var sb := MedievalTheme.flat(Color.RED, Color.BLUE, 4, 1, 10, 8)
	assert_int(int(sb.content_margin_left)).is_equal(MedievalTheme.px(10))
	assert_int(int(sb.content_margin_top)).is_equal(MedievalTheme.px(8))
	assert_int(sb.corner_radius_top_left).is_equal(MedievalTheme.px(4))
	assert_int(sb.border_width_left).is_equal(MedievalTheme.px(1))


func test_plaque_has_hard_shadow() -> void:
	var sb := MedievalTheme.plaque()
	assert_that(sb.shadow_color).is_equal(MedievalTheme.OAK_DEEP)
	assert_int(sb.shadow_size).is_equal(MedievalTheme.px(3))


func test_install_reaches_plain_label() -> void:
	MedievalTheme.install()
	var label: Label = auto_free(Label.new())
	add_child(label)
	assert_that(label.get_theme_color("font_color")).is_equal(MedievalTheme.INK)
	label.theme_type_variation = &"Title"
	assert_that(label.get_theme_color("font_color")).is_equal(MedievalTheme.CREAM)
