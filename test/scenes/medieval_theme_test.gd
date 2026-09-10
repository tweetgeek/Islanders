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


## Zasada podziału: marginesy wewnętrzne to przestrzeń między rzeczami (gap), promień
## i obramowanie to rozmiar samej rzeczy (px). Test przypina ją, żeby późniejsza zmiana
## nie przeniosła po cichu jednego do drugiego.
func test_flat_takes_margins_from_gap_and_shape_from_px() -> void:
	var sb := MedievalTheme.flat(Color.RED, Color.BLUE, 4, 1, 10, 8)
	assert_int(int(sb.content_margin_left)).is_equal(MedievalTheme.gap(10))
	assert_int(int(sb.content_margin_top)).is_equal(MedievalTheme.gap(8))
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


func test_gap_scales_by_scale_and_density() -> void:
	assert_int(MedievalTheme.gap(10.0)).is_equal(19)   # 10 × 2,77 × 0,7 = 19,39
	assert_int(MedievalTheme.gap(0.0)).is_equal(0)
	assert_float(MedievalTheme.DENSITY).is_greater(0.0)
	assert_float(MedievalTheme.DENSITY).is_less_equal(1.0)


func test_gap_never_exceeds_px() -> void:
	for v in range(1, 41):
		assert_int(MedievalTheme.gap(float(v))).is_less_equal(MedievalTheme.px(float(v)))


func test_container_separations_are_gaps() -> void:
	var t := MedievalTheme.build()
	assert_int(t.get_constant("separation", "VBoxContainer")).is_equal(MedievalTheme.gap(9))
	assert_int(t.get_constant("separation", "HBoxContainer")).is_equal(MedievalTheme.gap(6))
	# HSeparator to grubość linii, nie odstęp - zostaje przy px().
	assert_int(t.get_constant("separation", "HSeparator")).is_equal(MedievalTheme.px(1))


## Wciśnięty przycisk główny udaje zapadnięcie, przesuwając marginesy w przeciwne strony.
## Skok ma zostać trzema pikselami projektu niezależnie od gęstości, inaczej zagęszczenie
## zmniejszyłoby też skok i przycisk przestałby się widocznie wciskać.
func test_primary_press_travel_stays_three_design_pixels() -> void:
	var t := MedievalTheme.build()
	var normal: StyleBoxFlat = t.get_stylebox("normal", "Primary")
	var pressed: StyleBoxFlat = t.get_stylebox("pressed", "Primary")
	assert_int(int(normal.content_margin_top)).is_equal(MedievalTheme.gap(14))
	assert_int(int(pressed.content_margin_top - normal.content_margin_top)).is_equal(MedievalTheme.px(3))
	assert_int(int(normal.content_margin_bottom - pressed.content_margin_bottom)).is_equal(MedievalTheme.px(3))
