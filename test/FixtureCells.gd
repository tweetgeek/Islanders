class_name FixtureCells
extends RefCounted

## Komórki świata używane przez testy i smoke test; zgodne z fixtures/*.json i WorldGrid
## dla ziarna 1337. Jedyne miejsce definicji: zmiana algorytmu WorldGrid albo fixtures
## wymaga poprawki tylko tutaj.

const WORLD_SEED := 1337
## Osada domowa gracza (Koralowa, TROPICAL).
const HOME := Vector2i(80, 73)
## Druga własna osada (Popielna, VOLCANIC).
const OWN_SECOND := Vector2i(87, 72)
## Cudza osada (Szara Skała, gracz 9).
const FOREIGN := Vector2i(81, 73)
## Wyspa niczyja ze znaleziskiem.
const DEPOSIT := Vector2i(79, 73)
## Komórka morza.
const SEA := Vector2i(77, 68)


## Słownik world dla apply_world w testach.
static func world_json() -> Dictionary:
	return {
		"id": "w1", "seed": WORLD_SEED, "size": {"w": 200, "h": 200},
		"playerId": 7, "homeSettlement": {"x": HOME.x, "y": HOME.y},
	}
