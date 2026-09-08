class_name ApiProvider
extends RefCounted

## Interfejs źródła danych. Metody mogą być korutynami; wołaj je zawsze przez `await`.
## Zwracają `null` przy nieudanym pobraniu, w przeciwnym razie normalną wartość (sekcja 10 spec).


func fetch_world() -> Variant:
	return {}


func fetch_settlements() -> Variant:
	return []


func fetch_fleets() -> Variant:
	return []
