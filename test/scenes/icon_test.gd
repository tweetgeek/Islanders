extends GdUnitTestSuite

const SPEC_KINDS: Array[StringName] = [
	&"wood", &"stone", &"food", &"iron", &"sulfur",
	&"town_hall", &"barracks", &"shipyard", &"warehouse",
	&"anchor", &"map", &"fleet", &"people", &"gold",
	&"plus", &"minus", &"close", &"back",
	&"raid", &"trade", &"scout", &"colonize", &"return",
]


func test_spec_kinds_are_known() -> void:
	for k in SPEC_KINDS:
		assert_bool(Icon.is_known(k)).override_failure_message("nieznany kind %s" % k).is_true()
	assert_bool(Icon.is_known(&"nope")).is_false()


func test_icons_and_resource_icons_are_known() -> void:
	for r in ResourceTypes.ALL:
		assert_bool(Icon.is_known(ResourceTypes.ICONS[r])).is_true()
	for t in Buildings.Type.values():
		assert_bool(Icon.is_known(Buildings.icon(t))).is_true()


func test_every_kind_draws_one_frame() -> void:
	var root: Control = auto_free(Control.new())
	add_child(root)
	for k in Icon.KINDS:
		var icon := Icon.new()
		icon.kind = k
		icon.custom_minimum_size = Vector2(48, 48)
		root.add_child(icon)
	await await_idle_frame()
	assert_int(root.get_child_count()).is_equal(Icon.KINDS.size())
	# _draw() rozsyła po nazwie zbudowanej z kind, więc brak metody to cichy błąd w czasie
	# działania - sama liczba dzieci jest prawdziwa jeszcze zanim cokolwiek się narysuje.
	for icon: Icon in root.get_children():
		assert_bool(icon.has_method("_draw_" + String(icon.kind))) \
			.override_failure_message("brak metody _draw_%s" % icon.kind).is_true()


func test_icon_ignores_mouse() -> void:
	var icon: Icon = auto_free(Icon.new())
	assert_int(icon.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_into_button_adds_full_rect_child() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	var icon := Icon.into_button(button, &"close", Color.BLACK, 6.0)
	assert_object(icon.get_parent()).is_same(button)
	assert_float(icon.anchor_right).is_equal(1.0)
	assert_float(icon.offset_left).is_equal(6.0)
	assert_float(icon.offset_right).is_equal(-6.0)
