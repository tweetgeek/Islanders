extends GdUnitTestSuite

const SHEET := preload("res://scenes/ui/InspectSheet.tscn")
const FOREIGN := FixtureCells.FOREIGN
const EMPTY_WITH_DEPOSIT := FixtureCells.DEPOSIT
const SEA := FixtureCells.SEA


func before_test() -> void:
	GameState.reset()
	GameState.apply_world(FixtureCells.world_json())
	GameState.apply_settlements([{"x": FOREIGN.x, "y": FOREIGN.y, "ownerId": 9, "name": "Szara Skała"}])


func after_test() -> void:
	GameState.reset()


func _sheet() -> InspectSheet:
	var s: InspectSheet = auto_free(SHEET.instantiate())
	add_child(s)
	return s


func test_foreign_settlement_shows_public_data() -> void:
	var s := _sheet()
	assert_bool(s.open(FOREIGN)).is_true()
	assert_str(s.name_label.text).is_equal("Szara Skała")
	assert_str(s.subtitle.text).is_equal("(%d, %d) · gracz 9" % [FOREIGN.x, FOREIGN.y])
	assert_str(s.biome_badge.text).is_equal(Biome.key(GameState.island_at(FOREIGN).biome))
	assert_bool(s.public_label.visible).is_true()
	assert_bool(s.deposit_header.visible).is_false()
	assert_bool(s.empty_label.visible).is_false()


func test_unowned_island_with_deposit_lists_chips() -> void:
	var island := GameState.island_at(EMPTY_WITH_DEPOSIT)
	assert_object(island).is_not_null()
	assert_bool(island.has_deposit()).is_true()
	var s := _sheet()
	assert_bool(s.open(EMPTY_WITH_DEPOSIT)).is_true()
	assert_str(s.name_label.text).is_equal("Wyspa (%d, %d)" % [EMPTY_WITH_DEPOSIT.x, EMPTY_WITH_DEPOSIT.y])
	assert_str(s.subtitle.text).is_equal("(%d, %d) · wyspa niczyja" % [EMPTY_WITH_DEPOSIT.x, EMPTY_WITH_DEPOSIT.y])
	assert_bool(s.deposit_header.visible).is_true()
	assert_int(s.deposit_row.get_child_count()).is_equal(island.deposit.size())
	assert_bool(s.public_label.visible).is_false()


func test_sea_is_rejected() -> void:
	var s := _sheet()
	await assert_error(func() -> void: s.open(SEA)).is_push_error("InspectSheet: %s nie jest wyspą" % SEA)


func test_deposit_chip_uses_the_shared_builder() -> void:
	var s := _sheet()
	assert_bool(s.open(EMPTY_WITH_DEPOSIT)).is_true()
	var chip: PanelContainer = s.deposit_row.get_child(0)
	assert_str(String(chip.theme_type_variation)).is_equal("Chip")
	assert_object(SheetStyle.chip_amount(chip)).is_not_null()
	assert_str(SheetStyle.chip_amount(chip).text).is_not_empty()


## Regresja: chipy znaleziska były zwalniane samym queue_free(), więc dwa open() w jednej
## klatce zostawiały poprzedni komplet wciąż podpięty pod DepositRow.
func test_two_opens_in_one_frame_do_not_leave_stale_chips() -> void:
	var island := GameState.island_at(EMPTY_WITH_DEPOSIT)
	var s := _sheet()
	assert_bool(s.open(EMPTY_WITH_DEPOSIT)).is_true()
	assert_bool(s.open(EMPTY_WITH_DEPOSIT)).is_true()
	assert_int(s.deposit_row.get_child_count()).is_equal(island.deposit.size())
	await await_idle_frame()
