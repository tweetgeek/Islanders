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

## Budynek wspólny -> Icon.kind; budynki wydobywcze używają ikony swojego zasobu (patrz icon()).
const ICONS := {
	Type.TOWN_HALL: &"town_hall",
	Type.BARRACKS: &"barracks",
	Type.SHIPYARD: &"shipyard",
	Type.WAREHOUSE: &"warehouse",
}

const DESCRIPTIONS := {
	Type.TOWN_HALL: "Serce osady. Wyższy poziom podnosi limit poziomów pozostałych budynków.",
	Type.BARRACKS: "Szkoli jednostki lądowe do garnizonu osady.",
	Type.SHIPYARD: "Buduje statki. Każdy poziom przyspiesza budowę i odblokowuje większe kadłuby.",
	Type.WAREHOUSE: "Wyznacza pojemność magazynu dla każdego zasobu. Nadwyżka ponad limit przepada.",
	Type.SAWMILL: "Pozyskuje drewno z lasów wyspy.",
	Type.QUARRY: "Wydobywa kamień z nadbrzeżnych skał.",
	Type.FARM: "Uprawia tarasowe pola i dostarcza jedzenie.",
	Type.IRON_MINE: "Wydobywa żelazo z wulkanicznych żył.",
	Type.SULFUR_PIT: "Zbiera siarkę z fumaroli na zboczach wulkanu.",
}


static func icon(t: Type) -> StringName:
	if EXTRACTS.has(t):
		return ResourceTypes.ICONS[EXTRACTS[t]]
	return ICONS[t]


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
