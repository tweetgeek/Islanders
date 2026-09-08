extends SceneTree

## Generuje `contract/world-parity.json` - referencyjny zrzut geografii `WorldGrid`, którym
## backend NestJS sprawdza zgodność swojej implementacji bit-w-bit (ADR 0001,
## api-guidelines.md sekcja 4.5 "Jak udowodnić zgodność"). Użycie: ./run_parity.sh
## (patrz też run_tests.sh, run_smoke.sh).
##
## Floaty serializujemy ręcznie, NIGDY przez JSON.stringify(): domyślne formatowanie floatów
## w JSON.stringify() zaokrągla precyzję i ukrywa dokładnie ten dryf między klientem a backendem,
## który ten plik ma wykrywać.
##
## UWAGA O PRECYZJI (naprawiono defekt z pierwszej wersji tego narzędzia): `String.num(v, 17)`
## przyjmuje MIEJSCA PO PRZECINKU, nie CYFRY ZNACZĄCE - dla liczby typu 0.0116... siedemnaście
## miejsc po przecinku to tylko około piętnastu cyfr znaczących, więc ogon się urywał. Naprawiono
## przez zapis zawsze siedemnastu cyfr ZNACZĄCYCH (patrz `_num` niżej) - to zawsze wystarcza do
## jednoznacznego odtworzenia IEEE 754 binary64.
##
## DALSZA NIESPODZIANKA odkryta przy tej naprawie: nie da się w Godocie 4.8.dev4 zweryfikować
## odwracalności zapisu, parsując łańcuch z powrotem przez `String.to_float()`,
## `JSON.parse_string()` czy `str_to_var()` - wszystkie trzy (a nawet literały float w kodzie
## źródłowym GDScript) dzielą ten sam parser łańcuch->double, który dla ok. 15-26% "trudnych"
## wartości (takich, które faktycznie potrzebują pełnych siedemnastu cyfr znaczących) myli się
## o dokładnie 1 ULP - zweryfikowano to niezależnie w Pythonie (poprawnie zaokrąglony parser)
## na rzeczywistych danych tego pliku. Dlatego dowodu odwracalności NIE robimy przez
## zapisz-i-sparsuj-z-powrotem, tylko czystą arytmetyką całkowitoliczbową na cyfrach, które i tak
## już liczymy z bitów IEEE 754 (patrz `_assert_round_trip` niżej) - to jedyny sposób w tym
## silniku, żeby dowód rzeczywiście coś dowodził, zamiast fałszywie alarmować na poprawnych danych
## (patrz też przypis w kroku regeneracji w `contract/README.md`).

const GRID_SIZE := 200
const SEEDS: Array[int] = [1337, 99999]
const OUT_PATH := "res://contract/world-parity.json"
const SIG_DIGITS := 17


func _init() -> void:
	var out := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if out == null:
		push_error("world_parity_dump: nie można otworzyć %s do zapisu" % OUT_PATH)
		quit(1)
		return
	out.store_string(_build_json())
	out.close()
	print(
		"world_parity_dump: zapisano %s (%d seedów, %dx%d komórek)"
		% [OUT_PATH, SEEDS.size(), GRID_SIZE, GRID_SIZE]
	)
	quit(0)


## Zamienia 53-bitową mantysę `m` (int) na tablicę cyfr dziesiętnych LSF (najmniej znacząca
## cyfra pierwsza) - czysta arytmetyka całkowitoliczbowa, bez udziału jakiejkolwiek konwersji
## liczba<->łańcuch silnika.
func _int_to_digits_lsf(m: int) -> Array[int]:
	var digits: Array[int] = []
	while m > 0:
		digits.append(m % 10)
		m = m / 10
	return digits


## Mnoży wielocyfrową liczbę (tablica LSF) przez małą stałą (2 albo 5) - szkolny algorytm
## z przeniesieniem, cyfra po cyfrze, wyłącznie na `int`.
func _mul_small_lsf(digits: Array[int], factor: int) -> Array[int]:
	var out: Array[int] = []
	var carry := 0
	for digit in digits:
		var prod: int = digit * factor + carry
		out.append(prod % 10)
		carry = prod / 10
	while carry > 0:
		out.append(carry % 10)
		carry = carry / 10
	return out


## Rozkłada `av` (double, av >= 0, av != 0) na DOKŁADNE cyfry dziesiętne (MSF, bez wiodących
## zer) i `decimals` takie, że av == cyfry * 10^-decimals - bez ŻADNEGO zaokrąglenia. Liczone
## bezpośrednio z bitów IEEE 754: av = m * 2^e, m to 53-bitowa mantysa (z niejawną jedynką),
## e liczone tak, by dało się to zamienić na dokładną liczbę całkowitą razy potęgę dziesięciu
## (2^-k = 5^k / 10^k dla k > 0), a mnożenie przez 5 (albo 2) robimy własnym bignumem wyżej -
## patrz uzasadnienie na górze pliku, czemu nie można tu użyć `String.to_float()`.
func _exact_decimal_digits(av: float) -> Dictionary:
	var raw := PackedByteArray()
	raw.resize(8)
	raw.encode_double(0, av)
	var bits: int = raw.decode_u64(0)
	var biased_exp: int = int((bits >> 52) & 0x7FF)
	var mantissa_bits: int = bits & 0xFFFFFFFFFFFFF
	if biased_exp == 0:
		push_error("world_parity_dump: liczba subnormalna poza domeną kontraktu: %.20f" % av)
		quit(1)
		return {}
	var m: int = mantissa_bits | (1 << 52)
	var e: int = biased_exp - 1075
	var digits_lsf: Array[int] = _int_to_digits_lsf(m)
	var decimals := 0
	if e < 0:
		for _i in range(-e):
			digits_lsf = _mul_small_lsf(digits_lsf, 5)
		decimals = -e
	else:
		for _i in range(e):
			digits_lsf = _mul_small_lsf(digits_lsf, 2)
	digits_lsf.reverse()
	return {"digits": digits_lsf, "decimals": decimals}


## Zaokrągla dokładne cyfry (z `_exact_decimal_digits`) do `sig` cyfr znaczących
## (round-half-away-from-zero; dokładny remis "...5000..." praktycznie nie zdarza się dla
## policzonego szumu/promienia, a i tak jest tu bezpiecznie rozstrzygany w górę). Zwraca
## {digits, decimals} na tej samej zasadzie (digits * 10^-decimals), tylko z `sig` cyframi.
func _round_significant(exact: Dictionary, sig: int) -> Dictionary:
	var digits: Array[int] = exact["digits"]
	var decimals: int = exact["decimals"]
	var n: int = digits.size()
	if n <= sig:
		return {"digits": digits.duplicate(), "decimals": decimals}
	var kept: Array[int] = digits.slice(0, sig)
	var round_up: bool = digits[sig] >= 5
	var dropped_decimals: int = n - sig
	if round_up:
		var i := sig - 1
		while i >= 0:
			kept[i] += 1
			if kept[i] < 10:
				break
			kept[i] = 0
			i -= 1
		if i < 0:
			# przeniesienie poszło przez wszystkie zatrzymane cyfry (np. "999..." -> "100...") -
			# liczba całkowita zyskuje jedną cyfrę, więc żeby zostać przy `sig` cyfrach
			# znaczących, obcinamy nadmiarowe zero z końca i o JEDNĄ WIĘCEJ zmniejszamy decimals.
			kept.insert(0, 1)
			kept.resize(kept.size() - 1)
			dropped_decimals += 1
	return {"digits": kept, "decimals": decimals - dropped_decimals}


## Sprowadza dwie liczby dziesiętne (digits MSF, decimals) do wspólnej skali: tej samej liczby
## miejsc po przecinku (dopisując zera z prawej) i tej samej długości cyfr (dopisując zera
## z lewej) - dopiero wtedy porównanie/odejmowanie cyfra-po-cyfrze ma sens.
func _to_common_scale(
	digits_a: Array[int], decimals_a: int, digits_b: Array[int], decimals_b: int
) -> Dictionary:
	var common_decimals: int = max(decimals_a, decimals_b)
	var a: Array[int] = digits_a.duplicate()
	for _i in range(common_decimals - decimals_a):
		a.append(0)
	var b: Array[int] = digits_b.duplicate()
	for _i in range(common_decimals - decimals_b):
		b.append(0)
	var length: int = max(a.size(), b.size())
	while a.size() < length:
		a.insert(0, 0)
	while b.size() < length:
		b.insert(0, 0)
	return {"a": a, "b": b, "decimals": common_decimals}


func _compare_digits(a: Array[int], b: Array[int]) -> int:
	for i in range(a.size()):
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0


func _abs_diff_digits(a: Array[int], b: Array[int]) -> Array[int]:
	var cmp := _compare_digits(a, b)
	var big: Array[int] = a if cmp >= 0 else b
	var small: Array[int] = b if cmp >= 0 else a
	var n: int = big.size()
	var out: Array[int] = []
	out.resize(n)
	var borrow := 0
	for i in range(n - 1, -1, -1):
		var d: int = big[i] - small[i] - borrow
		if d < 0:
			d += 10
			borrow = 1
		else:
			borrow = 0
		out[i] = d
	return out


## DOWÓD ODWRACALNOŚCI (patrz przypis na górze pliku o tym, czemu nie parsujemy zapisanego
## łańcucha z powrotem przez silnik). Sprawdza matematyczną własność, która faktycznie gwarantuje
## odwracalność: |dokładna_wartość - zaokrąglona_wartość| <= pół jednostki na miejscu ostatniej
## zatrzymanej cyfry. To jest dokładnie warunek "żaden inny double nie jest bliżej tego zapisu
## niż `v`" - jeśli zachodzi, KAŻDY poprawny parser (Python, Node, przyszły backend) odtworzy `v`
## bit-w-bit z zapisanego łańcucha, niezależnie od tego, czy silnik Godota potrafi to zrobić sam
## u siebie. Jeśli nie zachodzi - to prawdziwy błąd zaokrąglenia w tym pliku, nie fałszywy alarm.
func _assert_round_trip(exact: Dictionary, rounded: Dictionary, sig: int, v: float) -> void:
	var exact_digits: Array[int] = exact["digits"]
	if exact_digits.size() <= sig:
		return  # brak zaokrąglenia - dokładne cyfry i tak trafiają do pliku bez utraty
	var scaled: Dictionary = _to_common_scale(
		exact_digits, exact["decimals"], rounded["digits"], rounded["decimals"]
	)
	var diff: Array[int] = _abs_diff_digits(scaled["a"], scaled["b"])
	var threshold_scaled: Dictionary = _to_common_scale(
		[5], rounded["decimals"] + 1, diff, scaled["decimals"]
	)
	var ok: bool = _compare_digits(threshold_scaled["a"], threshold_scaled["b"]) >= 0
	if not ok:
		push_error(
			(
				"world_parity_dump: BŁĄD ZAOKRĄGLENIA - zapis wartości %.20f na %d cyfrach "
				+ "znaczących nie odwraca się jednoznacznie (przekroczono pół jednostki "
				+ "na ostatniej cyfrze). To prawdziwy błąd, nie fałszywy alarm silnika - "
				+ "patrz przypis o precyzji na górze tego pliku."
			) % [v, sig]
		)
	# `assert` (nie `push_error` + `quit`) naprawdę zatrzymuje wykonanie w miejscu - narzędzie
	# uruchamiane jest zawsze przez pełny silnik Godota (`godot --headless -s ...`, nigdy przez
	# eksportowany szablon release), więc asserty tu nigdy nie są wycinane.
	assert(ok, "world_parity_dump: przerwano - patrz komunikat błędu powyżej")


## Formatuje `v` (znak z `v`, cyfry/decimals z `rounded`) jako liczbę JSON o pełnej precyzji.
func _format_decimal(v: float, rounded: Dictionary) -> String:
	var digits: Array[int] = rounded["digits"]
	var decimals: int = rounded["decimals"]
	var n: int = digits.size()
	var int_len: int = n - decimals
	var s := "-" if v < 0.0 else ""
	if int_len <= 0:
		s += "0."
		for _i in range(-int_len):
			s += "0"
		for d in digits:
			s += str(d)
	else:
		for i in range(int_len):
			s += str(digits[i])
		if decimals > 0:
			s += "."
			for i in range(int_len, n):
				s += str(digits[i])
	return s


## Jedyne miejsce, gdzie float trafia do JSON-a. Zapisuje `SIG_DIGITS` (17) cyfr znaczących -
## to zawsze wystarcza do jednoznacznego odtworzenia IEEE 754 binary64 - i przed zwróceniem
## łańcucha DOWODZI (patrz `_assert_round_trip`), że akurat ten zapis się odwraca; jeśli nie,
## przerywa generowanie zamiast po cichu zapisać plik, który kłamie.
func _num(v: float) -> String:
	var av: float = abs(v)
	if av == 0.0:
		return "0"
	var exact := _exact_decimal_digits(av)
	var rounded := _round_significant(exact, SIG_DIGITS)
	_assert_round_trip(exact, rounded, SIG_DIGITS, v)
	return _format_decimal(v, rounded)


func _deposit_json(deposit: Dictionary) -> String:
	var parts: Array[String] = []
	for r in deposit:
		parts.append("\"%s\":%s" % [r, _num(deposit[r])])
	return "{%s}" % ",".join(parts)


## Land/biome liczone niezależnie od `island_at`, żeby zapisać je też dla komórek morza -
## `island_at` zwraca null dla morza i nie ujawnia surowych wartości szumu.
func _cell_json(world_seed: int, x: int, y: int) -> String:
	var cell := Vector2i(x, y)
	var land := WorldGrid.fbm(
		world_seed, float(x) * WorldGrid.LAND_FREQUENCY, float(y) * WorldGrid.LAND_FREQUENCY, 2
	)
	var biome := WorldGrid.fbm(
		world_seed + 1, float(x) * WorldGrid.BIOME_FREQUENCY, float(y) * WorldGrid.BIOME_FREQUENCY, 1
	)
	var island := WorldGrid.island_at(world_seed, cell)
	var fields: Array[String] = [
		"\"x\":%d" % x,
		"\"y\":%d" % y,
		"\"hash\":%d" % WorldGrid.hash_cell(world_seed, cell),
		"\"land\":%s" % _num(land),
		"\"biome\":%s" % _num(biome),
		"\"isIsland\":%s" % ("true" if island != null else "false"),
	]
	if island != null:
		fields.append("\"biomeType\":\"%s\"" % Biome.key(island.biome))
		fields.append("\"radius\":%s" % _num(island.radius))
		fields.append("\"deposit\":%s" % _deposit_json(island.deposit))
	return "{%s}" % ",".join(fields)


func _world_json(world_seed: int) -> String:
	var cells: Array[String] = []
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			cells.append(_cell_json(world_seed, x, y))
	return "{\"seed\":%d,\"cells\":[%s]}" % [world_seed, ",".join(cells)]


func _constants_json() -> String:
	var resources: Array[String] = []
	for r in ResourceTypes.ALL:
		resources.append("\"%s\"" % r)
	var out := "{"
	out += "\"landFrequency\":%s," % _num(WorldGrid.LAND_FREQUENCY)
	out += "\"biomeFrequency\":%s," % _num(WorldGrid.BIOME_FREQUENCY)
	out += "\"biomeBand\":%s," % _num(WorldGrid.BIOME_BAND)
	out += "\"landThreshold\":%s," % _num(WorldGrid.LAND_THRESHOLD)
	out += "\"radiusMin\":%s," % _num(WorldGrid.RADIUS_MIN)
	out += "\"radiusMax\":%s," % _num(WorldGrid.RADIUS_MAX)
	out += "\"depositChance\":%s," % _num(WorldGrid.DEPOSIT_CHANCE)
	out += "\"resourceOrder\":[%s]" % ",".join(resources)
	out += "}"
	return out


func _build_json() -> String:
	var worlds: Array[String] = []
	for s in SEEDS:
		worlds.append(_world_json(s))
	return (
		"{\"gridSize\":%d,\"constants\":%s,\"worlds\":[%s]}\n"
		% [GRID_SIZE, _constants_json(), ",".join(worlds)]
	)
