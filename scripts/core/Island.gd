class_name Island
extends RefCounted

## Geografia wyspy, liczona z seeda świata (ADR 0001). Nigdy nie przychodzi z API.
var coord: Vector2i = Coord.NONE
var seed_val: int = 0
var biome: Biome.Type = Biome.Type.TEMPERATE
var radius: float = 80.0
## Znalezisko: zasób -> ilość. Pusty słownik = brak.
var deposit: Dictionary = {}


func has_deposit() -> bool:
	return not deposit.is_empty()
