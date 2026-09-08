extends GdUnitTestSuite

const SEED := 1337


func test_island_at_is_deterministic() -> void:
	var a := WorldGrid.island_at(SEED, Vector2i(103, 100))
	var b := WorldGrid.island_at(SEED, Vector2i(103, 100))
	assert_object(a).is_not_null()
	assert_int(a.seed_val).is_equal(b.seed_val)
	assert_int(a.biome).is_equal(b.biome)
	assert_float(a.radius).is_equal(b.radius)
	assert_that(a.deposit).is_equal(b.deposit)


func test_known_cells_for_fixture_seed() -> void:
	assert_object(WorldGrid.island_at(SEED, Vector2i(100, 100))).is_null()
	assert_int(
		WorldGrid.island_at(SEED, Vector2i(103, 100)).biome
	).is_equal(Biome.Type.TROPICAL)
	assert_int(
		WorldGrid.island_at(SEED, Vector2i(94, 100)).biome
	).is_equal(Biome.Type.VOLCANIC)
	assert_int(
		WorldGrid.island_at(SEED, Vector2i(95, 100)).biome
	).is_equal(Biome.Type.TEMPERATE)


func test_density_between_10_and_25_percent() -> void:
	var count := 0
	for x in 100:
		for y in 100:
			if WorldGrid.island_at(SEED, Vector2i(x, y)) != null:
				count += 1
	assert_int(count).is_between(1000, 2500)


func test_all_biomes_present() -> void:
	var seen := {}
	for x in 100:
		for y in 100:
			var isl := WorldGrid.island_at(SEED, Vector2i(x, y))
			if isl != null:
				seen[isl.biome] = true
	assert_int(seen.size()).is_equal(3)


func test_radius_within_range() -> void:
	for x in 50:
		for y in 50:
			var isl := WorldGrid.island_at(SEED, Vector2i(x, y))
			if isl != null:
				assert_float(isl.radius).is_between(
					WorldGrid.RADIUS_MIN, WorldGrid.RADIUS_MAX
				)


func test_deposit_only_foreign_resources() -> void:
	var deposits := 0
	for x in 100:
		for y in 100:
			var isl := WorldGrid.island_at(SEED, Vector2i(x, y))
			if isl == null or not isl.has_deposit():
				continue
			deposits += 1
			assert_int(isl.deposit.size()).is_between(1, 2)
			for r in isl.deposit:
				assert_bool(
					Biome.resources(isl.biome).has(r)
				).is_false()
				assert_float(isl.deposit[r]).is_between(200.0, 1000.0)
	assert_int(deposits).is_greater(100)


func test_cell_world_roundtrip() -> void:
	for c in [Vector2i(0, 0), Vector2i(10, 15), Vector2i(199, 199)]:
		assert_that(
			WorldGrid.world_to_cell(WorldGrid.cell_to_world(c))
		).is_equal(c)
	assert_that(
		WorldGrid.cell_to_world(Vector2i(0, 0))
	).is_equal(Vector2(128, 128))


func test_chunk_of_handles_negatives() -> void:
	assert_that(WorldGrid.chunk_of(Vector2i(0, 0))).is_equal(Vector2i(0, 0))
	assert_that(WorldGrid.chunk_of(Vector2i(7, 8))).is_equal(Vector2i(0, 1))
	assert_that(WorldGrid.chunk_of(Vector2i(-1, -1))).is_equal(Vector2i(-1, -1))


func test_in_bounds() -> void:
	var size := Vector2i(200, 200)
	assert_bool(WorldGrid.in_bounds(Vector2i(0, 0), size)).is_true()
	assert_bool(WorldGrid.in_bounds(Vector2i(199, 199), size)).is_true()
	assert_bool(WorldGrid.in_bounds(Vector2i(200, 0), size)).is_false()
	assert_bool(WorldGrid.in_bounds(Vector2i(-1, 5), size)).is_false()


func test_hash_cell_deterministic_and_positive() -> void:
	var h := WorldGrid.hash_cell(SEED, Vector2i(5, 7))
	assert_int(h).is_equal(WorldGrid.hash_cell(SEED, Vector2i(5, 7)))
	assert_int(h).is_greater_equal(0)
	assert_int(h).is_not_equal(WorldGrid.hash_cell(SEED, Vector2i(7, 5)))


## GOLDEN VALUES chroniące ADR 0001: to nie są arbitralne przykłady, tylko dosłowny zapis
## tego, co dziś produkuje WorldGrid dla seeda SEED. Radius i deposit potrafią dryfować przy
## zmianie stałej albo kolejności iteracji (np. ResourceTypes.ALL) nawet gdy biom się nie zmienia
## i inne testy dalej przechodzą - stąd osobne przypięcie. NIE aktualizować tych liczb pod nowe
## zachowanie bez świadomej decyzji o migracji świata; zmiana tego testu na zielono bez takiej
## decyzji oznacza, że właśnie zepsuto kontrakt klient-serwer.
func test_golden_radius_and_deposit_for_fixture_seed() -> void:
	var a := WorldGrid.island_at(SEED, Vector2i(103, 100))
	assert_int(a.biome).is_equal(Biome.Type.TROPICAL)
	assert_float(a.radius).is_equal_approx(107.34186069751175, 0.0000001)
	assert_that(a.deposit).is_equal({"stone": 527.0})

	var b := WorldGrid.island_at(SEED, Vector2i(94, 100))
	assert_int(b.biome).is_equal(Biome.Type.VOLCANIC)
	assert_float(b.radius).is_equal_approx(82.73408613970221, 0.0000001)
	assert_that(b.deposit).is_equal({})

	var c := WorldGrid.island_at(SEED, Vector2i(95, 100))
	assert_int(c.biome).is_equal(Biome.Type.TEMPERATE)
	assert_float(c.radius).is_equal_approx(65.64604776656341, 0.0000001)
	assert_that(c.deposit).is_equal({})

	var d := WorldGrid.island_at(SEED, Vector2i(91, 97))
	assert_int(d.biome).is_equal(Biome.Type.VOLCANIC)
	assert_float(d.radius).is_equal_approx(79.9510342760068, 0.0000001)
	assert_that(d.deposit).is_equal({"wood": 815.0, "stone": 598.0})

	var e := WorldGrid.island_at(SEED, Vector2i(2, 25))
	assert_int(e.biome).is_equal(Biome.Type.TEMPERATE)
	assert_float(e.radius).is_equal_approx(102.35035475167382, 0.0000001)
	assert_that(e.deposit).is_equal({"sulfur": 532.0})
