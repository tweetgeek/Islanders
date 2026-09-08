class_name Buildings
extends RefCounted

enum Type { TOWN_HALL, BARRACKS, SHIPYARD, WAREHOUSE, SAWMILL, QUARRY, FARM, IRON_MINE, SULFUR_PIT }

const COMMON: Array[Type] = [Type.TOWN_HALL, Type.BARRACKS, Type.SHIPYARD, Type.WAREHOUSE]

const KEYS := {
	Type.TOWN_HALL: "TOWN_HALL",
	Type.BARRACKS: "BARRACKS",
	Type.SHIPYARD: "SHIPYARD",
	Type.WAREHOUSE: "WAREHOUSE",
	Type.SAWMILL: "SAWMILL",
	Type.QUARRY: "QUARRY",
	Type.FARM: "FARM",
	Type.IRON_MINE: "IRON_MINE",
	Type.SULFUR_PIT: "SULFUR_PIT",
}

const LABELS := {
	Type.TOWN_HALL: "Ratusz",
	Type.BARRACKS: "Koszary",
	Type.SHIPYARD: "Stocznia",
	Type.WAREHOUSE: "Magazyn",
	Type.SAWMILL: "Tartak",
	Type.QUARRY: "Kamieniołom",
	Type.FARM: "Farma",
	Type.IRON_MINE: "Kopalnia żelaza",
	Type.SULFUR_PIT: "Wyrobisko siarki",
}

## Budynek wydobywczy -> zasób, który produkuje.
const EXTRACTS := {
	Type.SAWMILL: "wood",
	Type.QUARRY: "stone",
	Type.FARM: "food",
	Type.IRON_MINE: "iron",
	Type.SULFUR_PIT: "sulfur",
}


static func key(t: Type) -> String:
	return KEYS[t]


static func label(t: Type) -> String:
	return LABELS[t]


## Zwraca Type albo -1 dla nieznanego klucza.
static func from_key(k: String) -> int:
	for t in KEYS:
		if KEYS[t] == k:
			return t
	return -1


static func is_extraction(t: Type) -> bool:
	return EXTRACTS.has(t)
