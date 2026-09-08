class_name ResourceTypes
extends RefCounted

## Pięć zasobów gry. Klucze stringowe są identyczne z JSON z serwera.
const ALL: Array[String] = ["wood", "stone", "food", "iron", "sulfur"]

const COLORS := {
	"wood": Color(0.55, 0.35, 0.17),
	"stone": Color(0.55, 0.55, 0.58),
	"food": Color(0.85, 0.65, 0.2),
	"iron": Color(0.35, 0.38, 0.45),
	"sulfur": Color(0.9, 0.85, 0.25),
}

const LABELS := {
	"wood": "Drewno",
	"stone": "Kamień",
	"food": "Jedzenie",
	"iron": "Żelazo",
	"sulfur": "Siarka",
}

## Zasób -> Icon.kind
const ICONS := {
	"wood": &"wood",
	"stone": &"stone",
	"food": &"food",
	"iron": &"iron",
	"sulfur": &"sulfur",
}


static func is_valid(key: String) -> bool:
	return ALL.has(key)


## Słownik ze wszystkimi pięcioma kluczami ustawionymi na 0.0.
static func empty() -> Dictionary:
	var d := {}
	for k in ALL:
		d[k] = 0.0
	return d


## Uzupełnia brakujące klucze zerami, odrzuca nieznane klucze z ostrzeżeniem.
static func normalize(raw: Variant) -> Dictionary:
	var d := empty()
	if raw is Dictionary:
		for k in raw.keys():
			if is_valid(k):
				d[k] = float(raw[k])
			else:
				push_warning("ResourceTypes: nieznany zasób '%s'" % k)
	return d
