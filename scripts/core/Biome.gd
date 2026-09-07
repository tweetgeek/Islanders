class_name Biome
extends RefCounted

enum Type { TROPICAL, TEMPERATE, VOLCANIC }

const KEYS := {
	Type.TROPICAL: "TROPICAL",
	Type.TEMPERATE: "TEMPERATE",
	Type.VOLCANIC: "VOLCANIC",
}

## ADR 0002: każdy biom produkuje dokładnie dwa zasoby.
const RESOURCES := {
	Type.TROPICAL: ["wood", "food"],
	Type.TEMPERATE: ["stone", "food"],
	Type.VOLCANIC: ["iron", "sulfur"],
}

const EXTRACTION := {
	Type.TROPICAL: [Buildings.Type.SAWMILL, Buildings.Type.FARM],
	Type.TEMPERATE: [Buildings.Type.QUARRY, Buildings.Type.FARM],
	Type.VOLCANIC: [Buildings.Type.IRON_MINE, Buildings.Type.SULFUR_PIT],
}

const COLORS := {
	Type.TROPICAL: {
		"land": Color(0.24, 0.62, 0.30),
		"sand": Color(0.93, 0.86, 0.62),
		"coast": Color(0.72, 0.62, 0.38),
		"crater": Color.TRANSPARENT,
	},
	Type.TEMPERATE: {
		"land": Color(0.45, 0.58, 0.28),
		"sand": Color(0.82, 0.78, 0.60),
		"coast": Color(0.58, 0.53, 0.36),
		"crater": Color.TRANSPARENT,
	},
	Type.VOLCANIC: {
		"land": Color(0.28, 0.25, 0.26),
		"sand": Color(0.45, 0.40, 0.38),
		"coast": Color(0.25, 0.20, 0.20),
		"crater": Color(0.65, 0.15, 0.10),
	},
}

## Tylko dla MockProvider i placeholderów; prawdziwa produkcja przychodzi z serwera.
const MOCK_PRODUCTION := {
	Type.TROPICAL: {"wood": 120.0, "food": 200.0},
	Type.TEMPERATE: {"stone": 100.0, "food": 150.0},
	Type.VOLCANIC: {"iron": 60.0, "sulfur": 40.0},
}


static func key(b: Type) -> String:
	return KEYS[b]


## Nieznany klucz -> TEMPERATE z ostrzeżeniem, nigdy crash.
static func from_key(k: String) -> Type:
	for b in KEYS:
		if KEYS[b] == k:
			return b
	push_warning("Biome: nieznany biom '%s', używam TEMPERATE" % k)
	return Type.TEMPERATE


static func resources(b: Type) -> Array:
	return RESOURCES[b]


static func extraction_buildings(b: Type) -> Array:
	return EXTRACTION[b]


## Sześć slotów osady: cztery wspólne + dwa wydobywcze biomu, w stałej kolejności.
static func slots(b: Type) -> Array:
	var out: Array = []
	out.append_array(Buildings.COMMON)
	out.append_array(EXTRACTION[b])
	return out


static func colors(b: Type) -> Dictionary:
	return COLORS[b]


static func mock_production(b: Type) -> Dictionary:
	return ResourceTypes.normalize(MOCK_PRODUCTION[b])
