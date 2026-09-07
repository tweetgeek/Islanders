class_name ApiProvider
extends RefCounted

## Interfejs źródła danych. Metody mogą być korutynami; wołaj je zawsze przez `await`.


func fetch_world() -> Dictionary:
	return {}


func fetch_settlements() -> Array:
	return []


func fetch_fleets() -> Array:
	return []
