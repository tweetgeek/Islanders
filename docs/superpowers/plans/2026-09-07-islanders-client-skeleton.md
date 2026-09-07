# Islanders – szkielet klienta Godot 4: plan implementacji

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Działający szkielet klienta PoC: procedural mapa świata z chunkami i kamerą dotykową, widok wyspy ze slotami budynków, HUD z leniwym licznikiem zasobów i renderowanie mockowych flot, wszystko na danych z lokalnego mocka za wymiennym interfejsem API.

**Architecture:** Czysta logika (modele, generator konturu, siatka świata, nawigacja, czas) żyje w `scripts/core/` jako klasy `RefCounted` bez węzłów i jest w pełni testowana gdUnit4. Trzy autoloady (`GameState` jako jedyne źródło prawdy z sygnałami, `ApiClient` z providerem mock/HTTP, `SceneManager` do przełączania widoków) spinają sceny, które nigdy nie wołają siebie nawzajem. Geografia świata jest deterministyczna z seeda (ADR 0001), a tożsamość wyspy to `(worldId, x, y)`; z API przychodzi wyłącznie stan osad i flot.

**Tech Stack:** Godot 4.8 (dev4, GL Compatibility), GDScript 2.0 z typami, gdUnit4 v6.2.1 (headless CLI), JSON fixtures. Zero zewnętrznych assetów: `Polygon2D`, `Line2D`, `ColorRect`, `Label`, `_draw()`.

**Spec:** `docs/superpowers/specs/2026-09-07-islanders-client-skeleton-design.md` (terminologia: `CONTEXT.md`; decyzje: `docs/adr/0001-deterministic-world-geography.md`, `docs/adr/0002-biome-exclusive-resources.md`).

## Global Constraints

- Godot binarka: `/Applications/Godot.app/Contents/MacOS/Godot` (4.8.dev4). Skrypty `run_tests.sh` i `run_smoke.sh` czytają zmienną `GODOT`, jeśli chcesz podać inną ścieżkę.
- GDScript 2.0 z pełnymi typami (`var x: float = 0.0`, `-> void`), tabulatory jako wcięcia, linia do 120 znaków (`.vscode/settings.json` ma formatter).
- Zero zewnętrznych assetów graficznych; wszystko rysowane kodem.
- UI oddzielone od logiki: widoki słuchają sygnałów `GameState`, nigdy nie modyfikują modeli.
- Wszystkie znaczniki czasu to ISO 8601 UTC; jedynym miejscem czytającym zegar systemowy jest `TimeUtil`.
- `CONTEXT.md` ma pierwszeństwo w nazewnictwie: Island (geografia), Settlement (stan), Fleet, Deposit, Active Settlement, Inspected Island.
- Nazwy klas unikające kolizji z Godotem: `ResourceTypes` (nie `Resources`), `GameWorld` (nie `World`), `SeaNavigation` (nie `Navigation`). Nazwy metod nie mogą kolidować z `Object` (np. `_get`, `_set`, `get`).
- Wartości liczbowe z `JSON.parse_string` są `float`; w testach i kodzie rzutuj przez `int(...)` przed porównaniem z `int`.
- Każdy task kończy się zielonym `./run_tests.sh` (dla testów) lub zielonym `./run_smoke.sh` (dla scen) i commitem. Komunikaty commitów po angielsku, w trybie rozkazującym.
- Katalog `reports/` (raporty gdUnit4) jest w `.gitignore` i nigdy nie trafia do repo.

## Struktura plików

| Plik | Odpowiedzialność |
|---|---|
| `project.godot` | Autoloady, viewport 1080×1920, orientacja sensor, emulacja dotyku z myszy, ustawienia `islanders/api/*` |
| `run_tests.sh`, `run_smoke.sh` | Uruchamianie gdUnit4 i smoke testu scen headless |
| `scripts/core/TimeUtil.gd` | Zegar, parsowanie ISO 8601, formatowanie liczb i odliczania |
| `scripts/core/Coord.gd` | `Vector2i` ↔ klucz `"x:y"` ↔ JSON `{x, y}` |
| `scripts/core/ResourceTypes.gd` | Pięć zasobów, kolory, normalizacja słowników |
| `scripts/core/Buildings.gd` | Dziewięć budynków, etykiety, wspólne sloty |
| `scripts/core/Biome.gd` | Trzy biomy: zasoby, budynki wydobywcze, sloty, kolory |
| `scripts/core/CoastlineGenerator.gd` | Kontur wyspy z szumu, statyczny, bez węzłów |
| `scripts/core/Island.gd`, `WorldGrid.gd` | Deterministyczna geografia z seeda: istnienie, biom, promień, znalezisko, konwersje komórka↔piksele↔chunk |
| `scripts/core/GameWorld.gd`, `Settlement.gd`, `Fleet.gd` | Modele z `from_json` i lazy-eval |
| `scripts/core/SeaNavigation.gd` | Dystans, prędkość floty, czas podróży z wiatrem |
| `scripts/api/ApiProvider.gd`, `MockProvider.gd`, `HttpProvider.gd` | Interfejs danych, mock na fixtures, szkielet HTTP |
| `fixtures/*.json` | Świat, osady, floty mocka |
| `scenes/autoload/GameState.gd`, `ApiClient.gd`, `SceneManager.gd` | Store, ładowanie i resync, przełączanie widoków |
| `scenes/procedural/IslandGenerator.gd` | `@tool Node2D` rysujący wyspę, znalezisko i sloty |
| `scenes/procedural/FleetRenderer.gd` | `_draw()` tras i pozycji flot |
| `scenes/views/WorldMap.*`, `Water.gd`, `MapCamera.gd` | Mapa z chunkami, siatka wody, kamera dotykowa, tap |
| `scenes/views/IslandDetail.*`, `scenes/ui/BuildingMenu.*` | Detal wyspy w trzech trybach, panel budynku |
| `scenes/ui/HUD.*` | Pasek zasobów osady aktywnej |
| `scenes/views/Main.*` | Root: kontener widoków + HUD, start ładowania |
| `tools/Smoke.tscn`, `tools/smoke_probe.gd` | Headless smoke test przepływu scen |
| `test/**` | Testy gdUnit4 |

---

### Task 1: Konfiguracja projektu i gdUnit4

**Files:**
- Modify: `project.godot`
- Create: `.gitignore` (dopisz), `run_tests.sh`, `test/smoke_test.gd`
- Create: `addons/gdUnit4/` (skopiowane z wydania v6.2.1)

**Interfaces:**
- Produces: `./run_tests.sh [ścieżka]` uruchamia gdUnit4 headless; kod wyjścia 0 = wszystkie testy zielone, 100 = są porażki.

- [ ] **Krok 1: Zainstaluj gdUnit4 v6.2.1 do `addons/`**

```bash
git clone -q --depth 1 --branch v6.2.1 https://github.com/MikeSchulze/gdUnit4.git /tmp/gdunit4-src
mkdir -p addons
cp -r /tmp/gdunit4-src/addons/gdUnit4 addons/
rm -rf addons/gdUnit4/test
rm -rf /tmp/gdunit4-src
ls addons/gdUnit4/bin/GdUnitCmdTool.gd
```
Oczekiwane: plik `GdUnitCmdTool.gd` istnieje. Katalog `addons/gdUnit4/test` (testy własne frameworka) usuwamy, żeby nie odpalały się razem z naszymi.

- [ ] **Krok 2: Zastąp `project.godot` pełną konfiguracją**

Zastąp całą zawartość `project.godot` poniższą (sekcja `[autoload]` wskazuje pliki, które powstaną w Tasku 9 i 14; do tego czasu Godot wypisuje `Failed to instantiate an autoload`, ale testy działają normalnie):

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="Islanders"
run/main_scene="res://scenes/views/Main.tscn"
config/features=PackedStringArray("4.8", "GL Compatibility")
config/icon="res://icon.svg"

[autoload]

GameState="*res://scenes/autoload/GameState.gd"
ApiClient="*res://scenes/autoload/ApiClient.gd"
SceneManager="*res://scenes/autoload/SceneManager.gd"

[display]

window/size/viewport_width=1080
window/size/viewport_height=1920
window/size/window_width_override=540
window/size/window_height_override=960
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=6

[editor_plugins]

enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")

[input_devices]

pointing/emulate_touch_from_mouse=true
pointing/emulate_mouse_from_touch=false
joypads/ignore_joypad_on_unfocused_application=true

[islanders]

api/use_mock=true
api/base_url="http://localhost:3000"

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

rendering_device/driver.windows="d3d12"
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
lights_and_shadows/multi_bounce_occlusion/enabled=true
```

Znaczenie ustawień: `viewport 1080×1920` to bazowa rozdzielczość portretowa, `window_*_override 540×960` to rozmiar okna na desktopie, `handheld/orientation=6` to `SENSOR`, `emulate_touch_from_mouse=true` pozwala testować pan i tap myszą, `islanders/api/use_mock` wybiera providera.

- [ ] **Krok 3: Dopisz `reports/` do `.gitignore`**

```bash
printf 'reports/\n' >> .gitignore
cat .gitignore
```
Oczekiwane: trzy wpisy: `.godot/`, `/android/`, `reports/`.

- [ ] **Krok 4: Utwórz `run_tests.sh`**

Utwórz `run_tests.sh`:

```sh
#!/bin/sh
# Uruchamia testy gdUnit4 headless. Użycie: ./run_tests.sh [ścieżka, domyślnie test/]
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add "${1:-test/}"
```

```bash
chmod +x run_tests.sh
```

- [ ] **Krok 5: Napisz test dymny frameworka**

Utwórz `test/smoke_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_framework_runs() -> void:
	assert_int(1 + 1).is_equal(2)


func test_noise_is_deterministic() -> void:
	var n := FastNoiseLite.new()
	n.seed = 42
	assert_float(n.get_noise_2d(1.0, 2.0)).is_equal(n.get_noise_2d(1.0, 2.0))
```

- [ ] **Krok 6: Uruchom testy**

Uruchom: `./run_tests.sh test/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

Linie `ERROR: Failed to instantiate an autoload, can't load from path: res://scenes/autoload/...` są oczekiwane do Tasku 14 (pliki autoloadów jeszcze nie istnieją) i nie wpływają na wynik testów. Jeśli gdUnit4 nie startuje na 4.8 dev4, zatrzymaj się i zgłoś to użytkownikowi (spec, sekcja 11, ryzyko).

- [ ] **Krok 7: Commit**

```bash
git add project.godot .gitignore run_tests.sh test/smoke_test.gd addons/gdUnit4
git commit -m "Set up Godot project settings and gdUnit4 test runner"
```

---

### Task 2: TimeUtil i Coord

**Files:**
- Create: `scripts/core/TimeUtil.gd`, `scripts/core/Coord.gd`
- Test: `test/core/time_util_test.gd`, `test/core/coord_test.gd`

**Interfaces:**
- Produces: `TimeUtil.now() -> float`, `TimeUtil.set_server_time(server_unix: float)`, `TimeUtil.parse_iso8601(text: String) -> float`, `TimeUtil.to_iso8601(unix: float) -> String`, `TimeUtil.format_amount(value: float) -> String`, `TimeUtil.format_countdown(seconds: float) -> String`, statyczne pole `TimeUtil.server_time_offset: float`.
- Produces: `Coord.NONE: Vector2i`, `Coord.key(c: Vector2i) -> String`, `Coord.from_key(k: String) -> Vector2i`, `Coord.from_json(d: Variant) -> Vector2i`, `Coord.to_json(c: Vector2i) -> Dictionary`.

- [ ] **Krok 1: Napisz testy**

Utwórz `test/core/time_util_test.gd`:

```gdscript
extends GdUnitTestSuite

const UNIX_2026_09_07_12 := 1788782400.0


func test_parse_iso8601_with_z() -> void:
	assert_float(TimeUtil.parse_iso8601("2026-09-07T12:00:00Z")).is_equal(UNIX_2026_09_07_12)


func test_parse_iso8601_with_offset() -> void:
	assert_float(TimeUtil.parse_iso8601("2026-09-07T14:00:00+02:00")).is_equal(UNIX_2026_09_07_12)
	assert_float(TimeUtil.parse_iso8601("2026-09-07T10:00:00-02:00")).is_equal(UNIX_2026_09_07_12)


func test_parse_iso8601_with_milliseconds() -> void:
	assert_float(TimeUtil.parse_iso8601("2026-09-07T12:00:00.123Z")).is_equal(UNIX_2026_09_07_12)


func test_to_iso8601_roundtrip() -> void:
	assert_str(TimeUtil.to_iso8601(UNIX_2026_09_07_12)).is_equal("2026-09-07T12:00:00Z")
	assert_float(TimeUtil.parse_iso8601(TimeUtil.to_iso8601(UNIX_2026_09_07_12))).is_equal(UNIX_2026_09_07_12)


func test_format_amount() -> void:
	assert_str(TimeUtil.format_amount(950.0)).is_equal("950")
	assert_str(TimeUtil.format_amount(1234.0)).is_equal("1.2k")
	assert_str(TimeUtil.format_amount(1500000.0)).is_equal("1.5M")


func test_format_countdown() -> void:
	assert_str(TimeUtil.format_countdown(125.0)).is_equal("02:05")
	assert_str(TimeUtil.format_countdown(-5.0)).is_equal("00:00")


func test_set_server_time_shifts_now() -> void:
	var before := TimeUtil.now()
	TimeUtil.set_server_time(before + 3600.0)
	assert_float(TimeUtil.now()).is_greater(before + 3599.0)
	TimeUtil.server_time_offset = 0.0
```

Utwórz `test/core/coord_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_key_roundtrip() -> void:
	var c := Vector2i(10, 15)
	assert_str(Coord.key(c)).is_equal("10:15")
	assert_that(Coord.from_key(Coord.key(c))).is_equal(c)


func test_from_json() -> void:
	assert_that(Coord.from_json({"x": 3, "y": 4})).is_equal(Vector2i(3, 4))
	assert_that(Coord.from_json({"x": 3})).is_equal(Coord.NONE)
	assert_that(Coord.from_json(null)).is_equal(Coord.NONE)


func test_from_key_invalid() -> void:
	assert_that(Coord.from_key("garbage")).is_equal(Coord.NONE)
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/core/`
Oczekiwane: FAIL, błędy parsowania `Identifier "TimeUtil" not declared` / `Coord`

- [ ] **Krok 3: Zaimplementuj TimeUtil i Coord**

Utwórz `scripts/core/TimeUtil.gd`:

```gdscript
class_name TimeUtil
extends RefCounted

## Jedyne miejsce w kliencie, które czyta zegar systemowy.
static var server_time_offset: float = 0.0


static func now() -> float:
	return Time.get_unix_time_from_system() + server_time_offset


## Kalibruje zegar klienta do czasu serwera (unix UTC).
static func set_server_time(server_unix: float) -> void:
	server_time_offset = server_unix - Time.get_unix_time_from_system()


## Parsuje ISO 8601 ("2026-09-07T12:00:00Z", "...+02:00", "...12:00:00.123Z") do unix (UTC).
static func parse_iso8601(text: String) -> float:
	var s := text.strip_edges()
	var offset_seconds := 0
	if s.ends_with("Z"):
		s = s.substr(0, s.length() - 1)
	elif s.length() > 19:
		var re := RegEx.create_from_string("([+-])(\\d{2}):?(\\d{2})$")
		var m := re.search(s)
		if m:
			var sign := 1 if m.get_string(1) == "+" else -1
			offset_seconds = sign * (int(m.get_string(2)) * 3600 + int(m.get_string(3)) * 60)
			s = s.substr(0, m.get_start())
	var dot := s.find(".")
	if dot >= 0:
		s = s.substr(0, dot)
	return float(Time.get_unix_time_from_datetime_string(s) - offset_seconds)


static func to_iso8601(unix: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(unix), false) + "Z"


## 950 -> "950", 1234 -> "1.2k", 1500000 -> "1.5M"
static func format_amount(value: float) -> String:
	var v := floorf(value)
	if v < 1000.0:
		return "%d" % int(v)
	if v < 1000000.0:
		return "%.1fk" % (v / 1000.0)
	return "%.1fM" % (v / 1000000.0)


static func format_countdown(seconds: float) -> String:
	var s := maxi(int(seconds), 0)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [s / 60, s % 60]
```

Utwórz `scripts/core/Coord.gd`:

```gdscript
class_name Coord
extends RefCounted

## Wartość "brak współrzędnych"; świat zaczyna się od (0, 0), więc (-1, -1) nigdy nie jest komórką.
const NONE := Vector2i(-1, -1)


static func key(c: Vector2i) -> String:
	return "%d:%d" % [c.x, c.y]


static func from_key(k: String) -> Vector2i:
	var parts := k.split(":")
	if parts.size() != 2:
		return NONE
	return Vector2i(int(parts[0]), int(parts[1]))


## {"x": 10, "y": 15} -> Vector2i(10, 15); brak pola -> NONE
static func from_json(d: Variant) -> Vector2i:
	if not (d is Dictionary) or not d.has("x") or not d.has("y"):
		return NONE
	return Vector2i(int(d["x"]), int(d["y"]))


static func to_json(c: Vector2i) -> Dictionary:
	return {"x": c.x, "y": c.y}
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/core/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Commit**

```bash
git add scripts/core/TimeUtil.gd scripts/core/Coord.gd test/core/time_util_test.gd test/core/coord_test.gd
git commit -m "Add TimeUtil and Coord core helpers"
```

---

### Task 3: ResourceTypes, Buildings, Biome

**Files:**
- Create: `scripts/core/ResourceTypes.gd`, `scripts/core/Buildings.gd`, `scripts/core/Biome.gd`
- Test: `test/core/biome_test.gd`

**Interfaces:**
- Consumes: nic (stałe).
- Produces: `ResourceTypes.ALL: Array[String]`, `ResourceTypes.COLORS`, `ResourceTypes.LABELS`, `ResourceTypes.empty() -> Dictionary`, `ResourceTypes.normalize(raw: Variant) -> Dictionary` (zawsze 5 kluczy `float`).
- Produces: `Buildings.Type` (enum 9 wartości), `Buildings.COMMON`, `Buildings.EXTRACTS`, `Buildings.key(t) -> String`, `Buildings.label(t) -> String`, `Buildings.from_key(k) -> int` (-1 gdy nieznany).
- Produces: `Biome.Type` (TROPICAL, TEMPERATE, VOLCANIC), `Biome.key(b)`, `Biome.from_key(k) -> Biome.Type` (fallback TEMPERATE), `Biome.resources(b) -> Array`, `Biome.extraction_buildings(b) -> Array`, `Biome.slots(b) -> Array` (6 elementów), `Biome.colors(b) -> Dictionary` (klucze `land`, `sand`, `coast`, `crater`), `Biome.mock_production(b) -> Dictionary`.

- [ ] **Krok 1: Napisz testy**

Utwórz `test/core/biome_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_each_biome_has_two_resources_and_two_extraction_buildings() -> void:
	for b in Biome.Type.values():
		assert_int(Biome.resources(b).size()).is_equal(2)
		assert_int(Biome.extraction_buildings(b).size()).is_equal(2)
		for t in Biome.extraction_buildings(b):
			assert_bool(Biome.resources(b).has(Buildings.EXTRACTS[t])).is_true()


func test_slots_are_six_with_common_first() -> void:
	var slots := Biome.slots(Biome.Type.VOLCANIC)
	assert_int(slots.size()).is_equal(6)
	assert_that(slots.slice(0, 4)).is_equal(Buildings.COMMON)
	assert_bool(slots.has(Buildings.Type.IRON_MINE)).is_true()
	assert_bool(slots.has(Buildings.Type.SAWMILL)).is_false()


func test_unknown_biome_falls_back_to_temperate() -> void:
	assert_int(Biome.from_key("XYZ")).is_equal(Biome.Type.TEMPERATE)
	assert_int(Biome.from_key("VOLCANIC")).is_equal(Biome.Type.VOLCANIC)


func test_mock_production_has_all_five_keys() -> void:
	var p := Biome.mock_production(Biome.Type.TROPICAL)
	assert_int(p.size()).is_equal(5)
	assert_float(p["wood"]).is_greater(0.0)
	assert_float(p["iron"]).is_equal(0.0)


func test_resource_types_normalize_drops_unknown_keys() -> void:
	var d := ResourceTypes.normalize({"wood": 5, "gold": 9})
	assert_int(d.size()).is_equal(5)
	assert_float(d["wood"]).is_equal(5.0)
	assert_bool(d.has("gold")).is_false()


func test_buildings_key_roundtrip() -> void:
	for t in Buildings.Type.values():
		assert_int(Buildings.from_key(Buildings.key(t))).is_equal(t)
	assert_int(Buildings.from_key("CASTLE")).is_equal(-1)
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/core/biome_test.gd`
Oczekiwane: FAIL, `Identifier "Biome" not declared`

- [ ] **Krok 3: Zaimplementuj trzy klasy stałych**

Utwórz `scripts/core/ResourceTypes.gd`:

```gdscript
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
```

Utwórz `scripts/core/Buildings.gd`:

```gdscript
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
```

Utwórz `scripts/core/Biome.gd`:

```gdscript
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
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/core/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Commit**

```bash
git add scripts/core/ResourceTypes.gd scripts/core/Buildings.gd scripts/core/Biome.gd test/core/biome_test.gd
git commit -m "Add resource, building and biome definitions"
```

---

### Task 4: CoastlineGenerator

**Files:**
- Create: `scripts/core/CoastlineGenerator.gd`
- Test: `test/core/coastline_generator_test.gd`

**Interfaces:**
- Produces: `CoastlineGenerator.generate(seed_val: int, radius: float, points: int = 48, roughness: float = 0.35) -> PackedVector2Array`, `CoastlineGenerator.scaled(points, factor) -> PackedVector2Array`, `CoastlineGenerator.bay_angle(points) -> float`, `CoastlineGenerator.hash01(seed_val: int) -> float`, `CoastlineGenerator.ellipse_factor(seed_val) -> float`, stałe `ELLIPSE_MIN = 0.8`, `ELLIPSE_MAX = 1.2`.

Szum próbkowany na okręgu jednostkowym (`cos θ, sin θ`) gwarantuje zamknięcie konturu bez szwu. Zmierzony zakres szumu `TYPE_SIMPLEX_SMOOTH` z 3 oktawami to ok. ±0,6, więc przy `roughness = 0.35` promień waha się o ±21 %.

- [ ] **Krok 1: Napisz testy**

Utwórz `test/core/coastline_generator_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_deterministic_for_same_seed() -> void:
	assert_that(CoastlineGenerator.generate(84920, 100.0)).is_equal(CoastlineGenerator.generate(84920, 100.0))


func test_different_seeds_differ() -> void:
	assert_that(CoastlineGenerator.generate(1, 100.0)).is_not_equal(CoastlineGenerator.generate(2, 100.0))


func test_point_count() -> void:
	assert_int(CoastlineGenerator.generate(7, 100.0, 32).size()).is_equal(32)


func test_radii_within_bounds() -> void:
	var radius := 100.0
	var roughness := 0.35
	for seed_val in [1, 42, 84920, 1337]:
		var pts := CoastlineGenerator.generate(seed_val, radius, 48, roughness)
		for p in pts:
			assert_float(p.length()).is_between(radius * (1.0 - roughness) * CoastlineGenerator.ELLIPSE_MIN, radius * (1.0 + roughness) * CoastlineGenerator.ELLIPSE_MAX)


func test_polygon_is_triangulable() -> void:
	for seed_val in [1, 42, 84920, 1337, 99999]:
		var pts := CoastlineGenerator.generate(seed_val, 100.0, 48, 0.4)
		assert_int(Geometry2D.triangulate_polygon(pts).size()).is_greater(0)


func test_scaled_multiplies_points() -> void:
	var pts := PackedVector2Array([Vector2(1, 2), Vector2(-3, 4)])
	assert_that(CoastlineGenerator.scaled(pts, 2.0)).is_equal(PackedVector2Array([Vector2(2, 4), Vector2(-6, 8)]))


func test_bay_angle_points_to_closest_point() -> void:
	var pts := PackedVector2Array([Vector2(100, 0), Vector2(0, 50), Vector2(-100, 0), Vector2(0, -100)])
	assert_float(CoastlineGenerator.bay_angle(pts)).is_equal_approx(PI / 2.0, 0.001)
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/core/coastline_generator_test.gd`
Oczekiwane: FAIL, `Identifier "CoastlineGenerator" not declared`

- [ ] **Krok 3: Zaimplementuj generator**

Utwórz `scripts/core/CoastlineGenerator.gd`:

```gdscript
class_name CoastlineGenerator
extends RefCounted

const NOISE_SCALE := 2.0
const ELLIPSE_MIN := 0.8
const ELLIPSE_MAX := 1.2


## Deterministyczna liczba w [0, 1) z liczby całkowitej.
static func hash01(seed_val: int) -> float:
	var h: int = (seed_val ^ (seed_val >> 16)) * 0x45d9f3b
	h = (h ^ (h >> 16)) & 0x7fffffff
	return float(h % 10007) / 10007.0


static func ellipse_factor(seed_val: int) -> float:
	return ELLIPSE_MIN + (ELLIPSE_MAX - ELLIPSE_MIN) * hash01(seed_val)


## Zamknięty kontur wyspy: punkty na okręgu o promieniu zaburzonym szumem.
static func generate(seed_val: int, radius: float, points: int = 48, roughness: float = 0.35) -> PackedVector2Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	noise.frequency = 1.0
	var ellipse := ellipse_factor(seed_val)
	var out := PackedVector2Array()
	out.resize(points)
	for i in points:
		var t := float(i) / float(points) * TAU
		var n := noise.get_noise_2d(cos(t) * NOISE_SCALE, sin(t) * NOISE_SCALE)
		var r := radius * (1.0 + roughness * n)
		out[i] = Vector2(cos(t) * r, sin(t) * r * ellipse)
	return out


static func scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = points[i] * factor
	return out


## Kąt (rad) punktu konturu najbliższego środka: tam leży "zatoka" na stocznię.
static func bay_angle(points: PackedVector2Array) -> float:
	var best := 0
	for i in points.size():
		if points[i].length() < points[best].length():
			best = i
	return points[best].angle()
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/core/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Commit**

```bash
git add scripts/core/CoastlineGenerator.gd test/core/coastline_generator_test.gd
git commit -m "Add noise-based coastline generator"
```

---

### Task 5: Island i WorldGrid

**Files:**
- Create: `scripts/core/Island.gd`, `scripts/core/WorldGrid.gd`
- Test: `test/core/world_grid_test.gd`

**Interfaces:**
- Consumes: `Biome`, `ResourceTypes`, `Coord` (Task 2–3).
- Produces: `Island` z polami `coord: Vector2i`, `seed_val: int`, `biome: Biome.Type`, `radius: float`, `deposit: Dictionary`, metoda `has_deposit() -> bool`.
- Produces: `WorldGrid.CELL_SIZE = 256.0`, `WorldGrid.CHUNK_SIZE = 8`, `WorldGrid.RADIUS_MIN/MAX`, `WorldGrid.island_at(world_seed: int, cell: Vector2i) -> Island` (null = morze), `WorldGrid.hash_cell(world_seed, cell) -> int`, `WorldGrid.hash01(h) -> float`, `WorldGrid.cell_to_world(cell) -> Vector2`, `WorldGrid.world_to_cell(pos) -> Vector2i`, `WorldGrid.chunk_of(cell) -> Vector2i`, `WorldGrid.in_bounds(cell, size) -> bool`.

Stałe zmierzone dla seeda 1337 na próbce 100×100: `LAND_FREQUENCY = 0.12` i `LAND_THRESHOLD = 0.30` dają ok. 19 % lądu. Dla tego seeda komórka `(100, 100)` jest morzem, `(103, 100)` TROPICAL, `(94, 100)` VOLCANIC, `(95, 100)` TEMPERATE; testy i fixtures (Task 8) na tym polegają. **Nie zmieniaj tych stałych ani algorytmu hasha bez aktualizacji ADR 0001**, bo backend ma mieć identyczną implementację.

- [ ] **Krok 1: Napisz testy**

Utwórz `test/core/world_grid_test.gd`:

```gdscript
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
	assert_int(WorldGrid.island_at(SEED, Vector2i(103, 100)).biome).is_equal(Biome.Type.TROPICAL)
	assert_int(WorldGrid.island_at(SEED, Vector2i(94, 100)).biome).is_equal(Biome.Type.VOLCANIC)
	assert_int(WorldGrid.island_at(SEED, Vector2i(95, 100)).biome).is_equal(Biome.Type.TEMPERATE)


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
				assert_float(isl.radius).is_between(WorldGrid.RADIUS_MIN, WorldGrid.RADIUS_MAX)


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
				assert_bool(Biome.resources(isl.biome).has(r)).is_false()
				assert_float(isl.deposit[r]).is_between(200.0, 1000.0)
	assert_int(deposits).is_greater(100)


func test_cell_world_roundtrip() -> void:
	for c in [Vector2i(0, 0), Vector2i(10, 15), Vector2i(199, 199)]:
		assert_that(WorldGrid.world_to_cell(WorldGrid.cell_to_world(c))).is_equal(c)
	assert_that(WorldGrid.cell_to_world(Vector2i(0, 0))).is_equal(Vector2(128, 128))


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
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/core/world_grid_test.gd`
Oczekiwane: FAIL, `Identifier "WorldGrid" not declared`

- [ ] **Krok 3: Zaimplementuj Island i WorldGrid**

Utwórz `scripts/core/Island.gd`:

```gdscript
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
```

Utwórz `scripts/core/WorldGrid.gd`:

```gdscript
class_name WorldGrid
extends RefCounted

const CELL_SIZE := 256.0
const CHUNK_SIZE := 8
const LAND_FREQUENCY := 0.12
const LAND_THRESHOLD := 0.30
const BIOME_FREQUENCY := 0.03
const BIOME_BAND := 0.15
const DEPOSIT_CHANCE := 0.3
const RADIUS_MIN := 60.0
const RADIUS_MAX := 110.0

static var _noise_cache: Dictionary = {}


static func _noises(world_seed: int) -> Array:
	if not _noise_cache.has(world_seed):
		var land := FastNoiseLite.new()
		land.seed = world_seed
		land.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		land.fractal_octaves = 2
		land.frequency = LAND_FREQUENCY
		var biome := FastNoiseLite.new()
		biome.seed = world_seed + 1
		biome.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		biome.fractal_octaves = 1
		biome.frequency = BIOME_FREQUENCY
		_noise_cache[world_seed] = [land, biome]
	return _noise_cache[world_seed]


## Deterministyczny, 31-bitowy hash komórki; identyczny algorytm ma mieć backend.
static func hash_cell(world_seed: int, cell: Vector2i) -> int:
	var h: int = world_seed & 0x7fffffff
	h = (h * 31 + cell.x + 1000003) & 0x7fffffff
	h = (h * 31 + cell.y + 1000033) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h


static func hash01(h: int) -> float:
	return float(h % 10007) / 10007.0


## Wyspa w komórce albo null, gdy komórka jest morzem.
static func island_at(world_seed: int, cell: Vector2i) -> Island:
	var noises := _noises(world_seed)
	if noises[0].get_noise_2d(cell.x, cell.y) <= LAND_THRESHOLD:
		return null
	var h := hash_cell(world_seed, cell)
	var island := Island.new()
	island.coord = cell
	island.seed_val = h
	var b: float = noises[1].get_noise_2d(cell.x, cell.y)
	if b < -BIOME_BAND:
		island.biome = Biome.Type.TROPICAL
	elif b > BIOME_BAND:
		island.biome = Biome.Type.VOLCANIC
	else:
		island.biome = Biome.Type.TEMPERATE
	island.radius = RADIUS_MIN + (RADIUS_MAX - RADIUS_MIN) * hash01(h)
	island.deposit = _deposit_for(island.biome, h)
	return island


## Znalezisko zawiera 1-2 zasoby SPOZA biomu wyspy (ADR 0002).
static func _deposit_for(biome: Biome.Type, h: int) -> Dictionary:
	var h2 := hash_cell(h, Vector2i(7, 11))
	if hash01(h2) >= DEPOSIT_CHANCE:
		return {}
	var foreign: Array[String] = []
	for r in ResourceTypes.ALL:
		if not Biome.resources(biome).has(r):
			foreign.append(r)
	var h3 := hash_cell(h2, Vector2i(3, 5))
	var count := 1 + int(hash01(h3) * 2.0)
	var start := int(hash01(hash_cell(h3, Vector2i(1, 1))) * foreign.size())
	var out := {}
	for i in count:
		var r: String = foreign[(start + i) % foreign.size()]
		var h4 := hash_cell(h3, Vector2i(i + 1, 0))
		out[r] = float(200 + int(hash01(h4) * 800.0))
	return out


static func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / CELL_SIZE).floor())


static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE))


static func in_bounds(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/core/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Commit**

```bash
git add scripts/core/Island.gd scripts/core/WorldGrid.gd test/core/world_grid_test.gd
git commit -m "Add deterministic world grid with islands and deposits"
```

---

### Task 6: GameWorld i Settlement

**Files:**
- Create: `scripts/core/GameWorld.gd`, `scripts/core/Settlement.gd`
- Test: `test/core/settlement_test.gd`

**Interfaces:**
- Consumes: `Coord`, `TimeUtil`, `ResourceTypes`, `Buildings`, `Biome`, `WorldGrid`.
- Produces: `GameWorld.from_json(d: Dictionary) -> GameWorld` z polami `id: String`, `seed_val: int`, `size: Vector2i`, `wind: Vector2`, `status: String`, `player_id: int`, `home_settlement: Vector2i`, `server_time: float`; metoda `in_bounds(cell) -> bool`.
- Produces: `Settlement.from_json(d: Dictionary, biome_type: Biome.Type) -> Settlement` (null bez x/y) z polami `coord`, `world_id`, `owner_id`, `name`, `biome`, `is_own: bool`, `resources`, `production_per_hour`, `capacity: float`, `population: int`, `population_max: int`, `buildings: Dictionary` (Buildings.Type → poziom), `last_sync_at: float`; metody `current_resources(now: float) -> Dictionary`, `level(t: Buildings.Type) -> int`, `produces(resource: String) -> bool`.

`is_own` wynika z obecności klucza `resources` w JSON: cudze osady przychodzą wyłącznie jako dane publiczne. Budynek spoza slotów biomu jest ignorowany z ostrzeżeniem (ADR 0002).

- [ ] **Krok 1: Napisz testy**

Utwórz `test/core/settlement_test.gd`:

```gdscript
extends GdUnitTestSuite

const SYNC := "2026-09-07T12:00:00Z"
const SYNC_UNIX := 1788782400.0


func _own_json() -> Dictionary:
	return {
		"world": "w1", "x": 10, "y": 15, "ownerId": 7, "name": "Koralowa",
		"resources": {"wood": 500, "stone": 200, "food": 1000},
		"productionPerHour": {"wood": 120, "food": 200},
		"capacity": 8000, "population": 42, "populationMax": 120,
		"buildings": {"TOWN_HALL": 1, "SAWMILL": 2, "FARM": 1},
		"lastSyncAt": SYNC,
	}


func test_from_json_full() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	assert_object(s).is_not_null()
	assert_bool(s.is_own).is_true()
	assert_that(s.coord).is_equal(Vector2i(10, 15))
	assert_str(s.name).is_equal("Koralowa")
	assert_float(s.resources["wood"]).is_equal(500.0)
	assert_float(s.resources["iron"]).is_equal(0.0)
	assert_float(s.capacity).is_equal(8000.0)
	assert_int(s.level(Buildings.Type.SAWMILL)).is_equal(2)
	assert_int(s.level(Buildings.Type.BARRACKS)).is_equal(0)
	assert_float(s.last_sync_at).is_equal(SYNC_UNIX)


func test_from_json_public_only() -> void:
	var s := Settlement.from_json({"x": 1, "y": 2, "ownerId": 9, "name": "Obca"}, Biome.Type.VOLCANIC)
	assert_bool(s.is_own).is_false()
	assert_int(s.owner_id).is_equal(9)
	assert_float(s.current_resources(SYNC_UNIX)["wood"]).is_equal(0.0)


func test_from_json_without_coords_returns_null() -> void:
	assert_object(Settlement.from_json({"ownerId": 1}, Biome.Type.TEMPERATE)).is_null()


func test_building_outside_biome_is_ignored() -> void:
	var d := _own_json()
	d["buildings"]["QUARRY"] = 3
	var s := Settlement.from_json(d, Biome.Type.TROPICAL)
	assert_int(s.level(Buildings.Type.QUARRY)).is_equal(0)
	assert_int(s.level(Buildings.Type.SAWMILL)).is_equal(2)


func test_current_resources_at_sync_time() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	var r := s.current_resources(SYNC_UNIX)
	assert_float(r["wood"]).is_equal(500.0)
	assert_float(r["food"]).is_equal(1000.0)


func test_current_resources_after_two_hours() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	var r := s.current_resources(SYNC_UNIX + 7200.0)
	assert_float(r["wood"]).is_equal(740.0)
	assert_float(r["food"]).is_equal(1400.0)
	assert_float(r["stone"]).is_equal(200.0)


func test_current_resources_capped() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	var r := s.current_resources(SYNC_UNIX + 3600.0 * 1000.0)
	assert_float(r["wood"]).is_equal(8000.0)
	assert_float(r["food"]).is_equal(8000.0)


func test_current_resources_negative_delta_does_not_go_back() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	assert_float(s.current_resources(SYNC_UNIX - 3600.0)["wood"]).is_equal(500.0)


func test_produces() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	assert_bool(s.produces("wood")).is_true()
	assert_bool(s.produces("iron")).is_false()
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/core/settlement_test.gd`
Oczekiwane: FAIL, `Identifier "Settlement" not declared`

- [ ] **Krok 3: Zaimplementuj GameWorld i Settlement**

Utwórz `scripts/core/GameWorld.gd`:

```gdscript
class_name GameWorld
extends RefCounted

var id: String = ""
var seed_val: int = 0
var size: Vector2i = Vector2i(200, 200)
var wind: Vector2 = Vector2.ZERO
var status: String = "OPEN"
var player_id: int = 0
var home_settlement: Vector2i = Coord.NONE
var server_time: float = 0.0


static func from_json(d: Dictionary) -> GameWorld:
	var w := GameWorld.new()
	w.id = str(d.get("id", ""))
	w.seed_val = int(d.get("seed", 0))
	var sz: Variant = d.get("size", {})
	if sz is Dictionary:
		w.size = Vector2i(int(sz.get("w", 200)), int(sz.get("h", 200)))
	var wind: Variant = d.get("wind", {})
	if wind is Dictionary:
		w.wind = Vector2(float(wind.get("x", 0.0)), float(wind.get("y", 0.0)))
	w.status = str(d.get("status", "OPEN"))
	w.player_id = int(d.get("playerId", 0))
	w.home_settlement = Coord.from_json(d.get("homeSettlement"))
	if d.has("serverTime"):
		w.server_time = TimeUtil.parse_iso8601(str(d["serverTime"]))
	return w


func in_bounds(cell: Vector2i) -> bool:
	return WorldGrid.in_bounds(cell, size)
```

Utwórz `scripts/core/Settlement.gd`:

```gdscript
class_name Settlement
extends RefCounted

var coord: Vector2i = Coord.NONE
var world_id: String = ""
var owner_id: int = 0
var name: String = ""
var biome: Biome.Type = Biome.Type.TEMPERATE
## true, gdy JSON zawiera resources (osada własna); cudze osady mają tylko dane publiczne.
var is_own: bool = false
var resources: Dictionary = ResourceTypes.empty()
var production_per_hour: Dictionary = ResourceTypes.empty()
var capacity: float = 0.0
var population: int = 0
var population_max: int = 0
## Buildings.Type -> poziom. Brak klucza = poziom 0.
var buildings: Dictionary = {}
var last_sync_at: float = 0.0


## Zwraca null, gdy brakuje x/y. `biome` podaje GameState z WorldGrid; decyduje o dozwolonych budynkach.
static func from_json(d: Dictionary, biome_type: Biome.Type) -> Settlement:
	var coord := Coord.from_json(d)
	if coord == Coord.NONE:
		push_warning("Settlement: rekord bez x/y odrzucony")
		return null
	var s := Settlement.new()
	s.coord = coord
	s.world_id = str(d.get("world", ""))
	s.owner_id = int(d.get("ownerId", 0))
	s.name = str(d.get("name", ""))
	s.biome = biome_type
	s.is_own = d.has("resources")
	if s.is_own:
		s.resources = ResourceTypes.normalize(d.get("resources"))
		s.production_per_hour = ResourceTypes.normalize(d.get("productionPerHour"))
		s.capacity = float(d.get("capacity", 0.0))
		s.population = int(d.get("population", 0))
		s.population_max = int(d.get("populationMax", 0))
		s.last_sync_at = TimeUtil.parse_iso8601(str(d.get("lastSyncAt", "1970-01-01T00:00:00Z")))
		s.buildings = _parse_buildings(d.get("buildings", {}), biome_type)
	return s


static func _parse_buildings(raw: Variant, biome_type: Biome.Type) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	var allowed := Biome.slots(biome_type)
	for k in raw.keys():
		var t := Buildings.from_key(str(k))
		if t < 0 or not allowed.has(t):
			push_warning("Settlement: budynek '%s' niedozwolony w biomie %s, ignoruję" % [k, Biome.key(biome_type)])
			continue
		out[t] = int(raw[k])
	return out


## Lazy-eval: stored + rate * hours, obcięte do [0, capacity]. `now` zawsze jako argument.
func current_resources(now: float) -> Dictionary:
	var hours := maxf(now - last_sync_at, 0.0) / 3600.0
	var out := {}
	for k in ResourceTypes.ALL:
		var v: float = resources[k] + production_per_hour[k] * hours
		out[k] = clampf(v, 0.0, capacity)
	return out


func level(t: Buildings.Type) -> int:
	return int(buildings.get(t, 0))


func produces(resource: String) -> bool:
	return production_per_hour.get(resource, 0.0) > 0.0
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/core/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Commit**

```bash
git add scripts/core/GameWorld.gd scripts/core/Settlement.gd test/core/settlement_test.gd
git commit -m "Add GameWorld and Settlement models with lazy resource evaluation"
```

---

### Task 7: Fleet i SeaNavigation

**Files:**
- Create: `scripts/core/Fleet.gd`, `scripts/core/SeaNavigation.gd`
- Test: `test/core/fleet_test.gd`, `test/core/sea_navigation_test.gd`

**Interfaces:**
- Consumes: `Coord`, `TimeUtil`, `ResourceTypes`, `WorldGrid`.
- Produces: `Fleet.SHIP_SPEED: Dictionary` (`SLOOP: 8.0`, `GALLEON: 4.0` komórek/h), `Fleet.MISSIONS`, `Fleet.from_json(d) -> Fleet` (null bez id/from/to) z polami `id: String`, `world_id`, `owner_id: int`, `mission: String`, `from: Vector2i`, `to: Vector2i`, `ships: Dictionary`, `cargo_units`, `cargo_resources`, `depart_at: float`, `arrive_at: float`; metody `progress(now) -> float`, `position_at(now) -> Vector2`, `direction() -> Vector2`, `is_arrived(now) -> bool`, `is_own(player_id) -> bool`, `total_ships() -> int`, `remaining_seconds(now) -> float`.
- Produces: `SeaNavigation.distance(a, b) -> float`, `SeaNavigation.fleet_speed(ships: Dictionary) -> float`, `SeaNavigation.travel_time(a, b, speed_cells_per_hour, wind = Vector2.ZERO) -> float` (sekundy), stałe `WIND_FACTOR = 0.5`, `WIND_MIN = 0.5`, `WIND_MAX = 1.5`.

`arrive_at` przychodzi z serwera i klient go nie przelicza; `travel_time` służy do szacunków przed wysłaniem (przyszłe UI) i generowania fixtures.

- [ ] **Krok 1: Napisz testy**

Utwórz `test/core/fleet_test.gd`:

```gdscript
extends GdUnitTestSuite

const DEPART := 1788782400.0
const ARRIVE := DEPART + 3600.0


func _json() -> Dictionary:
	return {
		"id": "f1", "world": "w1", "ownerId": 7, "mission": "EXPEDITION",
		"from": {"x": 0, "y": 0}, "to": {"x": 4, "y": 0},
		"ships": {"SLOOP": 10, "GALLEON": 2},
		"cargo": {"units": {"MILITIA": 20}, "resources": {"iron": 300}},
		"departAt": "2026-09-07T12:00:00Z", "arriveAt": "2026-09-07T13:00:00Z",
	}


func test_from_json() -> void:
	var f := Fleet.from_json(_json())
	assert_object(f).is_not_null()
	assert_str(f.id).is_equal("f1")
	assert_that(f.to).is_equal(Vector2i(4, 0))
	assert_int(f.total_ships()).is_equal(12)
	assert_int(f.cargo_units["MILITIA"]).is_equal(20)
	assert_float(f.cargo_resources["iron"]).is_equal(300.0)
	assert_float(f.depart_at).is_equal(DEPART)
	assert_bool(f.is_own(7)).is_true()
	assert_bool(f.is_own(9)).is_false()


func test_from_json_missing_fields_returns_null() -> void:
	assert_object(Fleet.from_json({"id": "x", "from": {"x": 0, "y": 0}})).is_null()
	assert_object(Fleet.from_json({"from": {"x": 0, "y": 0}, "to": {"x": 1, "y": 1}})).is_null()


func test_incoming_fleet_without_ships() -> void:
	var d := _json()
	d.erase("ships")
	d.erase("cargo")
	var f := Fleet.from_json(d)
	assert_int(f.total_ships()).is_equal(0)


func test_progress() -> void:
	var f := Fleet.from_json(_json())
	assert_float(f.progress(DEPART - 100.0)).is_equal(0.0)
	assert_float(f.progress(DEPART + 1800.0)).is_equal(0.5)
	assert_float(f.progress(ARRIVE + 100.0)).is_equal(1.0)


func test_position_at_midpoint() -> void:
	var f := Fleet.from_json(_json())
	var expected := WorldGrid.cell_to_world(Vector2i(0, 0)).lerp(WorldGrid.cell_to_world(Vector2i(4, 0)), 0.5)
	assert_that(f.position_at(DEPART + 1800.0)).is_equal(expected)


func test_is_arrived_and_remaining() -> void:
	var f := Fleet.from_json(_json())
	assert_bool(f.is_arrived(ARRIVE - 1.0)).is_false()
	assert_bool(f.is_arrived(ARRIVE)).is_true()
	assert_float(f.remaining_seconds(DEPART + 600.0)).is_equal(3000.0)
	assert_float(f.remaining_seconds(ARRIVE + 600.0)).is_equal(0.0)
```

Utwórz `test/core/sea_navigation_test.gd`:

```gdscript
extends GdUnitTestSuite

const A := Vector2i(0, 0)
const B := Vector2i(4, 0)


func test_distance() -> void:
	assert_float(SeaNavigation.distance(A, B)).is_equal(4.0)
	assert_float(SeaNavigation.distance(Vector2i(0, 0), Vector2i(3, 4))).is_equal(5.0)


func test_zero_distance_is_zero_time() -> void:
	assert_float(SeaNavigation.travel_time(A, A, 4.0)).is_equal(0.0)


func test_calm_sea() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0)).is_equal(3600.0)


func test_tailwind_shortens() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(1, 0))).is_equal(2400.0)


func test_headwind_lengthens() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(-1, 0))).is_equal(7200.0)


func test_crosswind_neutral() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(0, 1))).is_equal(3600.0)


func test_wind_is_clamped() -> void:
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(5, 0))).is_equal(2400.0)
	assert_float(SeaNavigation.travel_time(A, B, 4.0, Vector2(-5, 0))).is_equal(7200.0)


func test_zero_speed_is_infinite() -> void:
	assert_bool(is_inf(SeaNavigation.travel_time(A, B, 0.0))).is_true()


func test_fleet_speed_is_slowest_ship() -> void:
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10, "GALLEON": 2})).is_equal(4.0)
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10})).is_equal(8.0)
	assert_float(SeaNavigation.fleet_speed({"SLOOP": 10, "GALLEON": 0})).is_equal(8.0)
	assert_float(SeaNavigation.fleet_speed({})).is_equal(0.0)
	assert_float(SeaNavigation.fleet_speed({"UNKNOWN": 3})).is_equal(0.0)
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/core/`
Oczekiwane: FAIL, `Identifier "Fleet" not declared` / `SeaNavigation`

- [ ] **Krok 3: Zaimplementuj Fleet i SeaNavigation**

Utwórz `scripts/core/Fleet.gd`:

```gdscript
class_name Fleet
extends RefCounted

## Prędkości w komórkach na godzinę. Do czasu, aż typów będzie więcej, tabela żyje tutaj.
const SHIP_SPEED := {"SLOOP": 8.0, "GALLEON": 4.0}
const MISSIONS: Array[String] = ["COLONIZE", "ATTACK", "TRANSPORT", "EXPEDITION", "RETURN"]

var id: String = ""
var world_id: String = ""
var owner_id: int = 0
var mission: String = "TRANSPORT"
var from: Vector2i = Coord.NONE
var to: Vector2i = Coord.NONE
## typ statku -> liczba; puste dla nadchodzącej cudzej floty
var ships: Dictionary = {}
var cargo_units: Dictionary = {}
var cargo_resources: Dictionary = {}
var depart_at: float = 0.0
var arrive_at: float = 0.0


## Zwraca null, gdy brakuje id, from lub to.
static func from_json(d: Dictionary) -> Fleet:
	var f := Fleet.new()
	f.id = str(d.get("id", ""))
	f.from = Coord.from_json(d.get("from"))
	f.to = Coord.from_json(d.get("to"))
	if f.id.is_empty() or f.from == Coord.NONE or f.to == Coord.NONE:
		push_warning("Fleet: rekord bez id/from/to odrzucony")
		return null
	f.world_id = str(d.get("world", ""))
	f.owner_id = int(d.get("ownerId", 0))
	f.mission = str(d.get("mission", "TRANSPORT"))
	if not MISSIONS.has(f.mission):
		push_warning("Fleet %s: nieznana misja '%s'" % [f.id, f.mission])
	var ships: Variant = d.get("ships", {})
	if ships is Dictionary:
		for k in ships.keys():
			f.ships[str(k)] = int(ships[k])
	var cargo: Variant = d.get("cargo", {})
	if cargo is Dictionary:
		var units: Variant = cargo.get("units", {})
		if units is Dictionary:
			for k in units.keys():
				f.cargo_units[str(k)] = int(units[k])
		f.cargo_resources = ResourceTypes.normalize(cargo.get("resources", {}))
	f.depart_at = TimeUtil.parse_iso8601(str(d.get("departAt", "1970-01-01T00:00:00Z")))
	f.arrive_at = TimeUtil.parse_iso8601(str(d.get("arriveAt", "1970-01-01T00:00:00Z")))
	return f


func progress(now: float) -> float:
	var total := arrive_at - depart_at
	if total <= 0.0:
		return 1.0
	return clampf((now - depart_at) / total, 0.0, 1.0)


func position_at(now: float) -> Vector2:
	return WorldGrid.cell_to_world(from).lerp(WorldGrid.cell_to_world(to), progress(now))


func direction() -> Vector2:
	return (WorldGrid.cell_to_world(to) - WorldGrid.cell_to_world(from)).normalized()


func is_arrived(now: float) -> bool:
	return now >= arrive_at


func is_own(player_id: int) -> bool:
	return owner_id == player_id


func total_ships() -> int:
	var n := 0
	for k in ships:
		n += int(ships[k])
	return n


func remaining_seconds(now: float) -> float:
	return maxf(arrive_at - now, 0.0)
```

Utwórz `scripts/core/SeaNavigation.gd`:

```gdscript
class_name SeaNavigation
extends RefCounted

const WIND_FACTOR := 0.5
const WIND_MIN := 0.5
const WIND_MAX := 1.5


static func distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


## Prędkość najwolniejszego znanego typu statku; 0.0 gdy flota pusta lub same nieznane typy.
static func fleet_speed(ships: Dictionary) -> float:
	var speed := INF
	for k in ships:
		if int(ships[k]) > 0 and Fleet.SHIP_SPEED.has(k):
			speed = minf(speed, Fleet.SHIP_SPEED[k])
	return 0.0 if speed == INF else speed


## Czas podróży w sekundach. Wiatr działa przez składową wzdłuż kierunku, ograniczoną do [0.5, 1.5] prędkości.
static func travel_time(a: Vector2i, b: Vector2i, speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float:
	var d := distance(a, b)
	if d == 0.0:
		return 0.0
	if speed_cells_per_hour <= 0.0:
		return INF
	var dir := Vector2(b - a).normalized()
	var factor := clampf(1.0 + WIND_FACTOR * wind.dot(dir), WIND_MIN, WIND_MAX)
	return d / (speed_cells_per_hour * factor) * 3600.0
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/core/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Commit**

```bash
git add scripts/core/Fleet.gd scripts/core/SeaNavigation.gd test/core/fleet_test.gd test/core/sea_navigation_test.gd
git commit -m "Add Fleet model and sea navigation with wind"
```

---

### Task 8: Warstwa API i fixtures

**Files:**
- Create: `scripts/api/ApiProvider.gd`, `scripts/api/MockProvider.gd`, `scripts/api/HttpProvider.gd`
- Create: `fixtures/world.json`, `fixtures/settlements.json`, `fixtures/fleets.json`
- Test: `test/api/mock_provider_test.gd`

**Interfaces:**
- Consumes: `TimeUtil`, `ResourceTypes`, `Coord`, `WorldGrid`, `Biome`, `Buildings`, `Fleet`.
- Produces: `ApiProvider` z metodami `fetch_world() -> Dictionary`, `fetch_settlements() -> Array`, `fetch_fleets() -> Array` (zawsze wołaj przez `await`).
- Produces: `MockProvider` (pole `clock: Callable` do testów, `MockProvider.advance(d: Dictionary, now: float)` statyczna), `HttpProvider.new(host: Node, url: String)`.

Fixtures leżą na komórkach, które `WorldGrid` dla seeda 1337 uznaje za ląd, a ich budynki pasują do biomu (test to sprawdza). Floty w fixtures mają `departOffsetMin` / `arriveOffsetMin` względem pierwszego załadowania; mock zamienia je na `departAt` / `arriveAt`. Osady w fixtures **nie mają** `lastSyncAt`: mock stempluje je „teraz” przy pierwszym pobraniu, a przy kolejnych (resync) przelicza zasoby jak prawdziwy serwer.

- [ ] **Krok 1: Utwórz fixtures**

Utwórz `fixtures/world.json`:

```json
{
  "id": "w1",
  "seed": 1337,
  "size": { "w": 200, "h": 200 },
  "wind": { "x": 0.3, "y": -0.1 },
  "status": "OPEN",
  "playerId": 7,
  "homeSettlement": { "x": 103, "y": 100 }
}
```

Utwórz `fixtures/settlements.json`:

```json
[
  {
    "world": "w1", "x": 103, "y": 100,
    "ownerId": 7, "name": "Koralowa",
    "resources": { "wood": 500, "stone": 200, "food": 1000, "iron": 40, "sulfur": 0 },
    "productionPerHour": { "wood": 120, "stone": 0, "food": 200, "iron": 0, "sulfur": 0 },
    "capacity": 8000,
    "population": 42, "populationMax": 120,
    "buildings": { "TOWN_HALL": 1, "BARRACKS": 0, "SHIPYARD": 1, "WAREHOUSE": 1, "SAWMILL": 2, "FARM": 1 }
  },
  {
    "world": "w1", "x": 94, "y": 100,
    "ownerId": 7, "name": "Popielna",
    "resources": { "wood": 120, "stone": 60, "food": 300, "iron": 900, "sulfur": 450 },
    "productionPerHour": { "wood": 0, "stone": 0, "food": 0, "iron": 60, "sulfur": 40 },
    "capacity": 4000,
    "population": 10, "populationMax": 60,
    "buildings": { "TOWN_HALL": 1, "WAREHOUSE": 1, "IRON_MINE": 2, "SULFUR_PIT": 1 }
  },
  {
    "world": "w1", "x": 95, "y": 100,
    "ownerId": 9, "name": "Szara Skała"
  }
]
```

Utwórz `fixtures/fleets.json`:

```json
[
  {
    "id": "f1", "world": "w1", "ownerId": 7, "mission": "EXPEDITION",
    "from": { "x": 103, "y": 100 }, "to": { "x": 94, "y": 99 },
    "ships": { "SLOOP": 6 },
    "cargo": { "units": {}, "resources": {} },
    "departOffsetMin": -10, "arriveOffsetMin": 30
  },
  {
    "id": "f2", "world": "w1", "ownerId": 7, "mission": "RETURN",
    "from": { "x": 95, "y": 98 }, "to": { "x": 94, "y": 100 },
    "ships": { "SLOOP": 4, "GALLEON": 1 },
    "cargo": { "units": {}, "resources": { "sulfur": 250, "wood": 120 } },
    "departOffsetMin": -5, "arriveOffsetMin": 15
  },
  {
    "id": "f3", "world": "w1", "ownerId": 9, "mission": "ATTACK",
    "from": { "x": 95, "y": 100 }, "to": { "x": 103, "y": 100 },
    "departOffsetMin": -20, "arriveOffsetMin": 120
  }
]
```

- [ ] **Krok 2: Napisz testy**

Utwórz `test/api/mock_provider_test.gd`:

```gdscript
extends GdUnitTestSuite

const NOW := 1788782400.0


func _provider(now: float = NOW) -> MockProvider:
	var p := MockProvider.new()
	p.clock = func() -> float: return now
	return p


func test_world_has_seed_and_server_time() -> void:
	var w := _provider().fetch_world()
	assert_str(w["id"]).is_equal("w1")
	assert_int(int(w["seed"])).is_equal(1337)
	assert_str(w["serverTime"]).is_equal("2026-09-07T12:00:00Z")


func test_settlements_are_stamped_with_now_on_first_fetch() -> void:
	var arr := _provider().fetch_settlements()
	assert_int(arr.size()).is_equal(3)
	for d in arr:
		if d.has("resources"):
			assert_str(d["lastSyncAt"]).is_equal("2026-09-07T12:00:00Z")


func test_settlements_lie_on_land_and_buildings_match_biome() -> void:
	var seed_val := int(_provider().fetch_world()["seed"])
	for d in _provider().fetch_settlements():
		var island := WorldGrid.island_at(seed_val, Coord.from_json(d))
		assert_object(island).is_not_null()
		var allowed := Biome.slots(island.biome)
		for k in d.get("buildings", {}).keys():
			assert_bool(allowed.has(Buildings.from_key(k))).override_failure_message("%s niedozwolony na %s" % [k, Coord.key(island.coord)]).is_true()


func test_second_fetch_advances_resources() -> void:
	var p := _provider()
	var first := p.fetch_settlements()
	p.clock = func() -> float: return NOW + 3600.0
	var second := p.fetch_settlements()
	assert_float(second[0]["resources"]["wood"]).is_equal(first[0]["resources"]["wood"] + 120.0)
	assert_str(second[0]["lastSyncAt"]).is_equal("2026-09-07T13:00:00Z")


func test_fleets_have_relative_times() -> void:
	var arr := _provider().fetch_fleets()
	assert_int(arr.size()).is_equal(3)
	var f := Fleet.from_json(arr[0])
	assert_float(f.depart_at).is_equal(NOW - 600.0)
	assert_float(f.arrive_at).is_equal(NOW + 1800.0)
	assert_bool(arr[0].has("departOffsetMin")).is_false()


func test_fleet_endpoints_lie_on_land() -> void:
	var seed_val := int(_provider().fetch_world()["seed"])
	for d in _provider().fetch_fleets():
		assert_object(WorldGrid.island_at(seed_val, Coord.from_json(d["from"]))).is_not_null()
		assert_object(WorldGrid.island_at(seed_val, Coord.from_json(d["to"]))).is_not_null()


func test_advance_caps_at_capacity() -> void:
	var d := {"resources": {"wood": 7950.0}, "productionPerHour": {"wood": 120.0}, "capacity": 8000.0, "lastSyncAt": "2026-09-07T12:00:00Z"}
	MockProvider.advance(d, NOW + 3600.0)
	assert_float(d["resources"]["wood"]).is_equal(8000.0)
```

- [ ] **Krok 3: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/api/`
Oczekiwane: FAIL, `Identifier "MockProvider" not declared`

- [ ] **Krok 4: Zaimplementuj providery**

Utwórz `scripts/api/ApiProvider.gd`:

```gdscript
class_name ApiProvider
extends RefCounted

## Interfejs źródła danych. Metody mogą być korutynami; wołaj je zawsze przez `await`.


func fetch_world() -> Dictionary:
	return {}


func fetch_settlements() -> Array:
	return []


func fetch_fleets() -> Array:
	return []
```

Utwórz `scripts/api/MockProvider.gd`:

```gdscript
class_name MockProvider
extends ApiProvider

const WORLD_PATH := "res://fixtures/world.json"
const SETTLEMENTS_PATH := "res://fixtures/settlements.json"
const FLEETS_PATH := "res://fixtures/fleets.json"

## Zegar wstrzykiwany w testach; domyślnie TimeUtil.now.
var clock: Callable = TimeUtil.now
var _settlements: Array = []
var _fleets: Array = []


static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("MockProvider: nie mogę odczytać %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("MockProvider: niepoprawny JSON w %s" % path)
	return parsed


func fetch_world() -> Dictionary:
	var d: Variant = load_json(WORLD_PATH)
	if not (d is Dictionary):
		return {}
	d["serverTime"] = TimeUtil.to_iso8601(clock.call())
	return d


## Pierwsze wywołanie stempluje lastSyncAt = now; kolejne przeliczają zasoby jak prawdziwy serwer.
func fetch_settlements() -> Array:
	var now: float = clock.call()
	if _settlements.is_empty():
		var arr: Variant = load_json(SETTLEMENTS_PATH)
		if not (arr is Array):
			return []
		_settlements = arr
		for d in _settlements:
			if d is Dictionary and d.has("resources"):
				d["lastSyncAt"] = TimeUtil.to_iso8601(now)
	else:
		for d in _settlements:
			if d is Dictionary and d.has("resources"):
				advance(d, now)
	return _settlements.duplicate(true)


## Fixture podaje departOffsetMin / arriveOffsetMin względem pierwszego załadowania.
func fetch_fleets() -> Array:
	if _fleets.is_empty():
		var now: float = clock.call()
		var arr: Variant = load_json(FLEETS_PATH)
		if not (arr is Array):
			return []
		_fleets = arr
		for d in _fleets:
			if d is Dictionary:
				d["departAt"] = TimeUtil.to_iso8601(now + float(d.get("departOffsetMin", 0)) * 60.0)
				d["arriveAt"] = TimeUtil.to_iso8601(now + float(d.get("arriveOffsetMin", 0)) * 60.0)
				d.erase("departOffsetMin")
				d.erase("arriveOffsetMin")
	return _fleets.duplicate(true)


## Symuluje serwer: resources += production * hours (do capacity), lastSyncAt = now.
static func advance(d: Dictionary, now: float) -> void:
	var last := TimeUtil.parse_iso8601(str(d.get("lastSyncAt", TimeUtil.to_iso8601(now))))
	var hours := maxf(now - last, 0.0) / 3600.0
	var res := ResourceTypes.normalize(d.get("resources"))
	var prod := ResourceTypes.normalize(d.get("productionPerHour"))
	var cap := float(d.get("capacity", 0.0))
	for k in ResourceTypes.ALL:
		res[k] = clampf(res[k] + prod[k] * hours, 0.0, cap)
	d["resources"] = res
	d["lastSyncAt"] = TimeUtil.to_iso8601(now)
```

Utwórz `scripts/api/HttpProvider.gd`:

```gdscript
class_name HttpProvider
extends ApiProvider

## Szkielet pod NestJS. HTTPRequest musi być w drzewie, więc provider dostaje węzeł-gospodarza.
var base_url: String
var _host: Node


func _init(host: Node, url: String) -> void:
	_host = host
	base_url = url.rstrip("/")


func _request_json(path: String) -> Variant:
	var req := HTTPRequest.new()
	_host.add_child(req)
	var err := req.request(base_url + path)
	if err != OK:
		req.queue_free()
		push_error("HttpProvider: request %s nieudany (%d)" % [path, err])
		return null
	var result: Array = await req.request_completed
	req.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		push_error("HttpProvider: %s -> result %d, status %d" % [path, result[0], result[1]])
		return null
	return JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())


func fetch_world() -> Dictionary:
	var d: Variant = await _request_json("/world")
	return d if d is Dictionary else {}


func fetch_settlements() -> Array:
	var a: Variant = await _request_json("/settlements")
	return a if a is Array else []


func fetch_fleets() -> Array:
	var a: Variant = await _request_json("/fleets")
	return a if a is Array else []
```

- [ ] **Krok 5: Uruchom testy**

Uruchom: `./run_tests.sh test/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 6: Commit**

```bash
git add scripts/api fixtures test/api/mock_provider_test.gd
git commit -m "Add API provider interface with mock fixtures and HTTP skeleton"
```

---

### Task 9: GameState (autoload)

**Files:**
- Create: `scenes/autoload/GameState.gd`
- Test: `test/state/game_state_test.gd`

**Interfaces:**
- Consumes: `GameWorld`, `Settlement`, `Fleet`, `Island`, `WorldGrid`, `Coord`.
- Produces (autoload `GameState`): sygnały `state_loaded`, `settlement_updated(coord: Vector2i)`, `fleets_updated`, `active_settlement_changed`, `inspected_island_changed(coord: Vector2i)`; pola `world: GameWorld`, `player_id: int`, `settlements: Dictionary` (Coord.key → Settlement), `fleets: Dictionary` (id → Fleet), `active_settlement: Settlement`, `inspected_coord: Vector2i`; metody `apply_world(d)`, `apply_settlements(arr)`, `apply_fleets(arr)`, `finish_loading()`, `set_active_settlement(coord) -> bool`, `inspect(coord)`, `settlement_at(coord) -> Settlement`, `island_at(coord) -> Island`, `own_settlements() -> Array`, `reset()`.

Autoload jest już wpisany w `project.godot` (Task 1). Test instancjonuje skrypt bezpośrednio (`preload(...).new()`), więc nie zależy od singletona.

- [ ] **Krok 1: Napisz testy**

Utwórz `test/state/game_state_test.gd`:

```gdscript
extends GdUnitTestSuite

const GameStateScript := preload("res://scenes/autoload/GameState.gd")


func _state() -> Node:
	var gs: Node = auto_free(GameStateScript.new())
	gs.apply_world({"id": "w1", "seed": 1337, "size": {"w": 200, "h": 200}, "playerId": 7, "homeSettlement": {"x": 103, "y": 100}})
	return gs


func _own(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y, "ownerId": 7, "name": "A", "resources": {}, "productionPerHour": {}, "capacity": 100, "lastSyncAt": "2026-09-07T12:00:00Z"}


func test_apply_world_sets_player() -> void:
	var gs := _state()
	assert_int(gs.player_id).is_equal(7)
	assert_that(gs.world.home_settlement).is_equal(Vector2i(103, 100))


func test_settlement_on_sea_is_rejected() -> void:
	var gs := _state()
	gs.apply_settlements([_own(100, 100)])
	assert_int(gs.settlements.size()).is_equal(0)


func test_settlement_on_land_is_stored_with_biome() -> void:
	var gs := _state()
	gs.apply_settlements([_own(103, 100)])
	var s: Settlement = gs.settlement_at(Vector2i(103, 100))
	assert_object(s).is_not_null()
	assert_int(s.biome).is_equal(Biome.Type.TROPICAL)


func test_finish_loading_activates_home() -> void:
	var gs := _state()
	gs.apply_settlements([_own(103, 100)])
	gs.finish_loading()
	assert_object(gs.active_settlement).is_not_null()
	assert_that(gs.active_settlement.coord).is_equal(Vector2i(103, 100))


func test_cannot_activate_foreign_settlement() -> void:
	var gs := _state()
	gs.apply_settlements([{"x": 95, "y": 100, "ownerId": 9, "name": "Obca"}])
	assert_bool(gs.set_active_settlement(Vector2i(95, 100))).is_false()
	assert_object(gs.active_settlement).is_null()


func test_apply_settlements_refreshes_active_reference() -> void:
	var gs := _state()
	gs.apply_settlements([_own(103, 100)])
	gs.finish_loading()
	var updated := _own(103, 100)
	updated["name"] = "Nowa"
	gs.apply_settlements([updated])
	assert_str(gs.active_settlement.name).is_equal("Nowa")


func test_apply_fleets_replaces_all() -> void:
	var gs := _state()
	gs.apply_fleets([{"id": "f1", "from": {"x": 0, "y": 0}, "to": {"x": 1, "y": 1}}, {"id": "bad"}])
	assert_int(gs.fleets.size()).is_equal(1)
	gs.apply_fleets([])
	assert_int(gs.fleets.size()).is_equal(0)


func test_inspect_emits_signal() -> void:
	var gs := _state()
	var received: Array = []
	gs.inspected_island_changed.connect(func(c: Vector2i) -> void: received.append(c))
	gs.inspect(Vector2i(5, 6))
	assert_that(gs.inspected_coord).is_equal(Vector2i(5, 6))
	assert_that(received).is_equal([Vector2i(5, 6)])


func test_island_at_out_of_bounds_is_null() -> void:
	var gs := _state()
	assert_object(gs.island_at(Vector2i(500, 500))).is_null()
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/state/`
Oczekiwane: FAIL, `Cannot preload resource` / brak pliku

- [ ] **Krok 3: Zaimplementuj GameState**

Utwórz `scenes/autoload/GameState.gd`:

```gdscript
extends Node

## Jedyne źródło prawdy o stanie gry po stronie klienta. Mutacje tylko przez metody apply_* / set_* / inspect.

signal state_loaded
signal settlement_updated(coord: Vector2i)
signal fleets_updated
signal active_settlement_changed
signal inspected_island_changed(coord: Vector2i)

var world: GameWorld = null
var player_id: int = 0
## Coord.key -> Settlement
var settlements: Dictionary = {}
## id -> Fleet
var fleets: Dictionary = {}
var active_settlement: Settlement = null
var inspected_coord: Vector2i = Coord.NONE


func apply_world(d: Dictionary) -> void:
	world = GameWorld.from_json(d)
	player_id = world.player_id


func apply_settlements(arr: Array) -> void:
	if world == null:
		push_error("GameState: apply_settlements przed apply_world")
		return
	for d in arr:
		if not (d is Dictionary):
			continue
		var coord := Coord.from_json(d)
		var island := island_at(coord)
		if island == null:
			push_error("GameState: osada na %s, a WorldGrid uznaje tę komórkę za morze; rekord odrzucony (ADR 0001)" % coord)
			continue
		var s := Settlement.from_json(d, island.biome)
		if s == null:
			continue
		settlements[Coord.key(coord)] = s
		if active_settlement != null and active_settlement.coord == coord:
			active_settlement = s
		settlement_updated.emit(coord)


func apply_fleets(arr: Array) -> void:
	fleets.clear()
	for d in arr:
		if not (d is Dictionary):
			continue
		var f := Fleet.from_json(d)
		if f != null:
			fleets[f.id] = f
	fleets_updated.emit()


## Wołane po pierwszym pełnym załadowaniu: osada domowa staje się aktywna.
func finish_loading() -> void:
	if world != null and active_settlement == null:
		set_active_settlement(world.home_settlement)
	state_loaded.emit()


## Zwraca false dla morza, wyspy bez osady i osady cudzej.
func set_active_settlement(coord: Vector2i) -> bool:
	var s := settlement_at(coord)
	if s == null or not s.is_own:
		push_error("GameState: %s nie jest własną osadą" % coord)
		return false
	active_settlement = s
	active_settlement_changed.emit()
	return true


func inspect(coord: Vector2i) -> void:
	inspected_coord = coord
	inspected_island_changed.emit(coord)


func settlement_at(coord: Vector2i) -> Settlement:
	return settlements.get(Coord.key(coord), null)


func island_at(coord: Vector2i) -> Island:
	if world == null or not world.in_bounds(coord):
		return null
	return WorldGrid.island_at(world.seed_val, coord)


func own_settlements() -> Array:
	var out: Array = []
	for s in settlements.values():
		if s.is_own:
			out.append(s)
	return out


## Tylko dla testów: przywraca stan początkowy.
func reset() -> void:
	world = null
	player_id = 0
	settlements.clear()
	fleets.clear()
	active_settlement = null
	inspected_coord = Coord.NONE
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Commit**

```bash
git add scenes/autoload/GameState.gd test/state/game_state_test.gd
git commit -m "Add GameState autoload as single source of truth"
```

---

### Task 10: IslandGenerator i FleetRenderer

**Files:**
- Create: `scenes/procedural/IslandGenerator.gd`, `scenes/procedural/FleetRenderer.gd`
- Test: `test/scenes/island_generator_test.gd`

**Interfaces:**
- Consumes: `CoastlineGenerator`, `Biome`, `Buildings`, `ResourceTypes`, `Settlement`, `Fleet`, `WorldGrid`, `TimeUtil`, autoload `GameState` (tylko FleetRenderer).
- Produces: `IslandGenerator` (`@tool`, `Node2D`) z eksportami `seed_val`, `radius`, `biome`, `show_slots`, `show_deposit`, polami `settlement: Settlement`, `deposit: Dictionary`, metodami `build()`, `slot_at(local_pos: Vector2) -> int` (-1 = brak), `contains(local_pos) -> bool`, statyczną `hexagon(r) -> PackedVector2Array`, stałą `POINTS = 48`. Węzły dzieci nazywają się `Shallow`, `Sand`, `Land`, `Crater` (tylko VOLCANIC), `Coast`, `Deposit`, `Slot_<KEY>`.
- Produces: `FleetRenderer` (`Node2D`) z metodą `refresh()`; rysuje w `_draw()`.

W grze zmiana eksportów **nie** przebudowuje wyspy (setter działa tylko w edytorze); po ustawieniu pól wołaj `build()`. Detekcja tapu na slocie to test odległości w `slot_at`, bez `Area2D`.

- [ ] **Krok 1: Napisz test generatora**

Utwórz `test/scenes/island_generator_test.gd`:

```gdscript
extends GdUnitTestSuite


func _generator(biome: Biome.Type, slots: bool) -> IslandGenerator:
	var gen: IslandGenerator = auto_free(IslandGenerator.new())
	gen.seed_val = 84920
	gen.radius = 100.0
	gen.biome = biome
	gen.show_slots = slots
	add_child(gen)
	return gen


func test_map_mode_draws_three_polygons_and_coast() -> void:
	var gen := _generator(Biome.Type.TROPICAL, false)
	assert_int(gen.get_child_count()).is_equal(4)
	assert_object(gen.get_node("Shallow")).is_instanceof(Polygon2D)
	assert_object(gen.get_node("Sand")).is_instanceof(Polygon2D)
	assert_object(gen.get_node("Land")).is_instanceof(Polygon2D)
	assert_object(gen.get_node("Coast")).is_instanceof(Line2D)
	assert_int((gen.get_node("Coast") as Line2D).points.size()).is_equal(IslandGenerator.POINTS)


func test_volcanic_adds_crater() -> void:
	var gen := _generator(Biome.Type.VOLCANIC, false)
	assert_object(gen.get_node_or_null("Crater")).is_not_null()


func test_slots_follow_biome() -> void:
	var gen := _generator(Biome.Type.VOLCANIC, true)
	assert_int(gen.get_child_count()).is_equal(5 + 6)
	assert_object(gen.get_node_or_null("Slot_IRON_MINE")).is_not_null()
	assert_object(gen.get_node_or_null("Slot_SAWMILL")).is_null()
	assert_int(gen.slot_at(Vector2.ZERO)).is_equal(Buildings.Type.TOWN_HALL)
	assert_int(gen.slot_at(Vector2(9999, 0))).is_equal(-1)


func test_deposit_marker_only_when_requested() -> void:
	var gen := _generator(Biome.Type.TEMPERATE, false)
	gen.deposit = {"iron": 300.0}
	gen.build()
	assert_object(gen.get_node_or_null("Deposit")).is_null()
	gen.show_deposit = true
	gen.build()
	assert_object(gen.get_node_or_null("Deposit")).is_not_null()


func test_rebuild_clears_previous_children() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	var before := gen.get_child_count()
	gen.build()
	assert_int(gen.get_child_count()).is_equal(before)


func test_settlement_levels_reach_labels() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	var s := Settlement.from_json({"x": 1, "y": 1, "resources": {}, "buildings": {"SAWMILL": 3}}, Biome.Type.TROPICAL)
	gen.settlement = s
	gen.build()
	var label: Label = gen.get_node("Slot_SAWMILL").get_child(2)
	assert_str(label.text).is_equal("Tartak\n3")
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/scenes/`
Oczekiwane: FAIL, `Identifier "IslandGenerator" not declared`

- [ ] **Krok 3: Zaimplementuj IslandGenerator**

Utwórz `scenes/procedural/IslandGenerator.gd`:

```gdscript
@tool
class_name IslandGenerator
extends Node2D

## Rysuje wyspę z (seed_val, radius, biome) wyłącznie z Polygon2D / Line2D / Label.
## W edytorze zmiana eksportu przebudowuje podgląd; w grze wołaj build() po ustawieniu pól.

const POINTS := 48
const SHALLOW_SCALE := 1.18
const LAND_SCALE := 0.78
const LAND_ROUGHNESS := 0.25
const CRATER_SCALE := 0.18
const SLOT_RING := 0.45
const SLOT_SIZE := 0.12
const SLOT_HIT := 1.4
const SHALLOW_COLOR := Color(0.55, 0.85, 0.95, 0.45)
const EMPTY_SLOT_FILL := Color(0.5, 0.5, 0.5, 0.35)
const EMPTY_SLOT_LINE := Color(0.6, 0.6, 0.6)

@export var seed_val: int = 1:
	set(v):
		seed_val = v
		_editor_rebuild()
@export var radius: float = 96.0:
	set(v):
		radius = v
		_editor_rebuild()
@export var biome: Biome.Type = Biome.Type.TROPICAL:
	set(v):
		biome = v
		_editor_rebuild()
@export var show_slots: bool = false:
	set(v):
		show_slots = v
		_editor_rebuild()
@export var show_deposit: bool = false:
	set(v):
		show_deposit = v
		_editor_rebuild()

## Osada (może być null): poziomy budynków w slotach.
var settlement: Settlement = null
## Znalezisko: zasób -> ilość.
var deposit: Dictionary = {}

var _coast := PackedVector2Array()
## Buildings.Type -> pozycja lokalna
var _slot_positions: Dictionary = {}


func _ready() -> void:
	build()


func _editor_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		build()


func build() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_slot_positions.clear()
	_coast = CoastlineGenerator.generate(seed_val, radius, POINTS)
	var colors := Biome.colors(biome)
	_add_polygon("Shallow", CoastlineGenerator.scaled(_coast, SHALLOW_SCALE), SHALLOW_COLOR)
	_add_polygon("Sand", _coast, colors["sand"])
	_add_polygon("Land", CoastlineGenerator.generate(seed_val, radius * LAND_SCALE, POINTS, LAND_ROUGHNESS), colors["land"])
	if biome == Biome.Type.VOLCANIC:
		_add_polygon("Crater", CoastlineGenerator.generate(seed_val + 1, radius * CRATER_SCALE, 16, 0.3), colors["crater"])
	var line := Line2D.new()
	line.name = "Coast"
	line.points = _coast
	line.closed = true
	line.width = 3.0
	line.default_color = colors["coast"]
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)
	if show_deposit and not deposit.is_empty():
		_add_deposit_marker()
	if show_slots:
		_build_slots()


func _add_polygon(node_name: String, points: PackedVector2Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = node_name
	poly.polygon = points
	poly.color = color
	add_child(poly)
	return poly


## Romb przy brzegu, po przeciwnej stronie niż zatoka, w kolorze pierwszego zasobu znaleziska.
func _add_deposit_marker() -> void:
	var angle := CoastlineGenerator.bay_angle(_coast) + PI
	var pos := Vector2.from_angle(angle) * radius * 0.85
	var s := radius * 0.1
	var marker := Polygon2D.new()
	marker.name = "Deposit"
	marker.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
	marker.position = pos
	marker.color = ResourceTypes.COLORS[deposit.keys()[0]]
	add_child(marker)


## Ratusz w centrum, 5 slotów na okręgu co 72°, stocznia w kierunku zatoki.
func _build_slots() -> void:
	var ring: Array = Biome.slots(biome).filter(func(t: int) -> bool: return t != Buildings.Type.TOWN_HALL)
	ring.erase(Buildings.Type.SHIPYARD)
	ring.insert(0, Buildings.Type.SHIPYARD)
	var bay := CoastlineGenerator.bay_angle(_coast)
	_slot_positions[Buildings.Type.TOWN_HALL] = Vector2.ZERO
	for i in ring.size():
		var a := bay + float(i) / float(ring.size()) * TAU
		_slot_positions[ring[i]] = Vector2.from_angle(a) * radius * SLOT_RING
	for t in _slot_positions:
		_add_slot(t, _slot_positions[t])


func _add_slot(t: Buildings.Type, pos: Vector2) -> void:
	var lvl := settlement.level(t) if settlement != null else 0
	var size := radius * SLOT_SIZE
	var node := Node2D.new()
	node.name = "Slot_" + Buildings.key(t)
	node.position = pos
	var hex := Polygon2D.new()
	hex.polygon = hexagon(size)
	hex.color = Biome.colors(biome)["land"].darkened(0.35) if lvl > 0 else EMPTY_SLOT_FILL
	node.add_child(hex)
	var outline := Line2D.new()
	outline.points = hexagon(size)
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color.WHITE if lvl > 0 else EMPTY_SLOT_LINE
	node.add_child(outline)
	var label := Label.new()
	label.text = "%s\n%d" % [Buildings.label(t), lvl] if lvl > 0 else Buildings.label(t)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 48)
	label.position = Vector2(-80, size + 4)
	label.add_theme_font_size_override("font_size", 16)
	node.add_child(label)
	add_child(node)


## Typ budynku pod pozycją lokalną albo -1.
func slot_at(local_pos: Vector2) -> int:
	for t in _slot_positions:
		if local_pos.distance_to(_slot_positions[t]) <= radius * SLOT_SIZE * SLOT_HIT:
			return t
	return -1


func contains(local_pos: Vector2) -> bool:
	return local_pos.length() <= radius * 1.1


static func hexagon(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 6:
		out.append(Vector2.from_angle(float(i) / 6.0 * TAU) * r)
	return out
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Zaimplementuj FleetRenderer**

Utwórz `scenes/procedural/FleetRenderer.gd`:

```gdscript
class_name FleetRenderer
extends Node2D

const OWN_COLOR := Color(1.0, 0.85, 0.2)
const INCOMING_COLOR := Color(0.95, 0.25, 0.2)
const DASH := 24.0
const TRIANGLE := 14.0
const FONT_SIZE := 16

var _fleets: Array = []


func _ready() -> void:
	refresh()


func refresh() -> void:
	_fleets = GameState.fleets.values()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var now := TimeUtil.now()
	var font := ThemeDB.fallback_font
	for f: Fleet in _fleets:
		if f.is_arrived(now):
			continue
		var a := WorldGrid.cell_to_world(f.from)
		var b := WorldGrid.cell_to_world(f.to)
		var color := OWN_COLOR if f.is_own(GameState.player_id) else INCOMING_COLOR
		draw_dashed_line(a, b, color, 2.0, DASH)
		var pos := f.position_at(now)
		var dir := f.direction()
		var tri := PackedVector2Array([
			pos + dir * TRIANGLE,
			pos + dir.rotated(2.5) * TRIANGLE * 0.7,
			pos + dir.rotated(-2.5) * TRIANGLE * 0.7,
		])
		draw_colored_polygon(tri, color)
		var text := "%s %s" % [f.mission.left(3), TimeUtil.format_countdown(f.remaining_seconds(now))]
		draw_string(font, pos + Vector2(-32, -TRIANGLE - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
```

FleetRenderer zależy od autoloadu `GameState`, więc weryfikujemy go w smoke teście w Tasku 14.

- [ ] **Krok 6: Sprawdź podgląd w edytorze (opcjonalnie, ręcznie)**

Otwórz projekt w Godocie, utwórz nową scenę z `Node2D`, przypnij `IslandGenerator.gd`, zmieniaj `seed_val` i `biome` w Inspektorze. Wyspa ma się przebudowywać na żywo. Sceny nie zapisuj.

- [ ] **Krok 7: Commit**

```bash
git add scenes/procedural test/scenes/island_generator_test.gd
git commit -m "Add procedural IslandGenerator node and FleetRenderer"
```

---

### Task 11: Mapa świata: kamera, woda, chunki

**Files:**
- Create: `scenes/views/MapCamera.gd`, `scenes/views/Water.gd`, `scenes/views/WorldMap.gd`, `scenes/views/WorldMap.tscn`
- Test: `test/scenes/map_camera_test.gd`

**Interfaces:**
- Consumes: `WorldGrid`, `Coord`, `IslandGenerator`, `FleetRenderer`, `Settlement`, autoloady `GameState`, `SceneManager` (Task 14: `show_island_detail()`).
- Produces: `MapCamera` (`Camera2D`) z sygnałem `tapped(world_pos: Vector2)`, metodami `set_bounds(rect: Rect2)`, `visible_world_rect() -> Rect2`, `screen_to_world(screen_pos) -> Vector2`, stałymi `ZOOM_MIN = 0.25`, `ZOOM_MAX = 2.0`.
- Produces: `WorldMap.tscn` z węzłami `Water`, `Chunks`, `Labels`, `Fleets`, `Camera`; skrypt z metodą `_on_tapped(world_pos)` (używaną też przez smoke test).

Tap = puszczenie palca po mniej niż 250 ms i przesunięciu poniżej 12 px. Pinch śledzi dwa dotyki w słowniku i zoomuje wokół ich środka. Chunki są liczone co 0,2 s z marginesem jednego chunka i spawnowane maksymalnie po 2 na klatkę.

- [ ] **Krok 1: Napisz test kamery**

Utwórz `test/scenes/map_camera_test.gd`:

```gdscript
extends GdUnitTestSuite


func _camera() -> MapCamera:
	var cam: MapCamera = auto_free(MapCamera.new())
	add_child(cam)
	return cam


func test_screen_to_world_at_center_is_camera_position() -> void:
	var cam := _camera()
	cam.position = Vector2(1000, 2000)
	var center := cam.get_viewport_rect().size / 2.0
	assert_that(cam.screen_to_world(center)).is_equal(Vector2(1000, 2000))


func test_zoom_is_clamped() -> void:
	var cam := _camera()
	cam._zoom_at(Vector2.ZERO, 100.0)
	assert_float(cam.zoom.x).is_equal(MapCamera.ZOOM_MAX)
	cam._zoom_at(Vector2.ZERO, 0.0001)
	assert_float(cam.zoom.x).is_equal(MapCamera.ZOOM_MIN)


func test_zoom_keeps_point_under_cursor() -> void:
	var cam := _camera()
	cam.position = Vector2(500, 500)
	var screen := Vector2(100, 100)
	var before := cam.screen_to_world(screen)
	cam._zoom_at(screen, 1.5)
	assert_that(cam.screen_to_world(screen)).is_equal_approx(before, Vector2(0.01, 0.01))


func test_bounds_clamp_position() -> void:
	var cam := _camera()
	cam.set_bounds(Rect2(0, 0, 10000, 10000))
	cam.position = Vector2(-5000, 20000)
	cam._clamp_position()
	var half := cam.get_viewport_rect().size / cam.zoom / 2.0
	assert_that(cam.position).is_equal(Vector2(half.x, 10000 - half.y))


func test_small_world_is_centered() -> void:
	var cam := _camera()
	cam.set_bounds(Rect2(0, 0, 100, 100))
	cam.position = Vector2(9999, 9999)
	cam._clamp_position()
	assert_that(cam.position).is_equal(Vector2(50, 50))
```

- [ ] **Krok 2: Uruchom testy, żeby zobaczyć porażkę**

Uruchom: `./run_tests.sh test/scenes/map_camera_test.gd`
Oczekiwane: FAIL, `Identifier "MapCamera" not declared`

- [ ] **Krok 3: Zaimplementuj MapCamera**

Utwórz `scenes/views/MapCamera.gd`:

```gdscript
class_name MapCamera
extends Camera2D

## Pan jednym palcem (lub LPM przez emulację), pinch dwoma, scroll myszy, tap z progiem czasu i dystansu.

signal tapped(world_pos: Vector2)

const ZOOM_MIN := 0.25
const ZOOM_MAX := 2.0
const TAP_MAX_TIME := 0.25
const TAP_MAX_DIST := 12.0
const INERTIA_DAMP := 6.0
const SCROLL_STEP := 1.1

## index dotyku -> pozycja ekranowa
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _velocity := Vector2.ZERO
var _press_time := 0.0
var _drag_dist := 0.0
var _bounds := Rect2()
var _has_bounds := false


func set_bounds(rect: Rect2) -> void:
	_bounds = rect
	_has_bounds = true
	_clamp_position()


func visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	return Rect2(position - size / 2.0, size)


func screen_to_world(screen_pos: Vector2) -> Vector2:
	return position + (screen_pos - get_viewport_rect().size / 2.0) / zoom


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, SCROLL_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / SCROLL_STEP)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_press_time = Time.get_ticks_msec() / 1000.0
			_drag_dist = 0.0
			_velocity = Vector2.ZERO
		elif _touches.size() == 2:
			var pts: Array = _touches.values()
			_pinch_dist = pts[0].distance_to(pts[1])
	else:
		var was_single := _touches.size() == 1
		_touches.erase(e.index)
		_pinch_dist = 0.0
		if was_single:
			var elapsed := Time.get_ticks_msec() / 1000.0 - _press_time
			if elapsed < TAP_MAX_TIME and _drag_dist < TAP_MAX_DIST:
				tapped.emit(screen_to_world(e.position))


func _on_drag(e: InputEventScreenDrag) -> void:
	_touches[e.index] = e.position
	_drag_dist += e.relative.length()
	if _touches.size() == 1:
		position -= e.relative / zoom
		var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
		_velocity = -e.relative / zoom / dt
	elif _touches.size() == 2:
		var pts: Array = _touches.values()
		var d: float = pts[0].distance_to(pts[1])
		if _pinch_dist > 0.0:
			_zoom_at((pts[0] + pts[1]) / 2.0, d / _pinch_dist)
		_pinch_dist = d
	_clamp_position()


func _process(delta: float) -> void:
	if _touches.is_empty() and _velocity.length() > 1.0:
		position += _velocity * delta
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(INERTIA_DAMP * delta, 0.0, 1.0))
		_clamp_position()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_pos)
	var z := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	position += before - screen_to_world(screen_pos)
	_clamp_position()


func _clamp_position() -> void:
	if not _has_bounds:
		return
	var half := get_viewport_rect().size / zoom / 2.0
	if _bounds.size.x <= half.x * 2.0:
		position.x = _bounds.get_center().x
	else:
		position.x = clampf(position.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	if _bounds.size.y <= half.y * 2.0:
		position.y = _bounds.get_center().y
	else:
		position.y = clampf(position.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
```

- [ ] **Krok 4: Uruchom testy**

Uruchom: `./run_tests.sh test/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

- [ ] **Krok 5: Zaimplementuj Water i WorldMap**

Utwórz `scenes/views/Water.gd`:

```gdscript
extends Node2D

## Siatka komórek w widocznym prostokącie; WorldMap ustawia visible_rect co klatkę.

const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.06)

var visible_rect := Rect2()


func _draw() -> void:
	var cs := WorldGrid.CELL_SIZE
	var x0 := floorf(visible_rect.position.x / cs) * cs
	var y0 := floorf(visible_rect.position.y / cs) * cs
	var x := x0
	while x <= visible_rect.end.x:
		draw_line(Vector2(x, visible_rect.position.y), Vector2(x, visible_rect.end.y), LINE_COLOR, 1.0)
		x += cs
	var y := y0
	while y <= visible_rect.end.y:
		draw_line(Vector2(visible_rect.position.x, y), Vector2(visible_rect.end.x, y), LINE_COLOR, 1.0)
		y += cs
```

Utwórz `scenes/views/WorldMap.gd`:

```gdscript
extends Node2D

const CHUNK_REFRESH := 0.2
const CHUNKS_PER_FRAME := 2
const LABEL_MIN_ZOOM := 0.6
const OWN_COLOR := Color(1.0, 0.85, 0.2)
const FOREIGN_COLOR := Color(0.85, 0.85, 0.9)

@onready var water: Node2D = $Water
@onready var chunks: Node2D = $Chunks
@onready var labels: Node2D = $Labels
@onready var fleets: FleetRenderer = $Fleets
@onready var camera: MapCamera = $Camera

## Vector2i chunk -> Node2D
var _loaded_chunks: Dictionary = {}
var _pending: Array[Vector2i] = []
var _refresh_accum := 0.0


func _ready() -> void:
	camera.tapped.connect(_on_tapped)
	GameState.settlement_updated.connect(_on_settlement_updated)
	GameState.fleets_updated.connect(fleets.refresh)
	if GameState.world != null:
		camera.set_bounds(Rect2(Vector2.ZERO, Vector2(GameState.world.size) * WorldGrid.CELL_SIZE))
	if GameState.active_settlement != null:
		camera.position = WorldGrid.cell_to_world(GameState.active_settlement.coord)
	_rebuild_labels()
	_refresh_chunks()


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= CHUNK_REFRESH:
		_refresh_accum = 0.0
		_refresh_chunks()
	_spawn_pending(CHUNKS_PER_FRAME)
	labels.visible = camera.zoom.x >= LABEL_MIN_ZOOM
	water.visible_rect = camera.visible_world_rect()
	water.queue_redraw()


func _refresh_chunks() -> void:
	var rect := camera.visible_world_rect().grow(WorldGrid.CELL_SIZE * WorldGrid.CHUNK_SIZE)
	var c0 := WorldGrid.chunk_of(WorldGrid.world_to_cell(rect.position))
	var c1 := WorldGrid.chunk_of(WorldGrid.world_to_cell(rect.end))
	var wanted := {}
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			wanted[Vector2i(cx, cy)] = true
	for key in _loaded_chunks.keys():
		if not wanted.has(key):
			_loaded_chunks[key].queue_free()
			_loaded_chunks.erase(key)
	for key in wanted:
		if not _loaded_chunks.has(key) and not _pending.has(key):
			_pending.append(key)


func _spawn_pending(max_count: int) -> void:
	for i in max_count:
		if _pending.is_empty():
			return
		var key: Vector2i = _pending.pop_front()
		if not _loaded_chunks.has(key):
			_spawn_chunk(key)


func _spawn_chunk(chunk: Vector2i) -> void:
	var node := Node2D.new()
	node.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	for y in WorldGrid.CHUNK_SIZE:
		for x in WorldGrid.CHUNK_SIZE:
			var cell := chunk * WorldGrid.CHUNK_SIZE + Vector2i(x, y)
			var island := GameState.island_at(cell)
			if island == null:
				continue
			var s := GameState.settlement_at(cell)
			var gen := IslandGenerator.new()
			gen.name = "Island_" + Coord.key(cell)
			gen.seed_val = island.seed_val
			gen.radius = island.radius
			gen.biome = island.biome
			gen.show_slots = false
			gen.show_deposit = s == null
			gen.deposit = island.deposit
			gen.position = WorldGrid.cell_to_world(cell)
			node.add_child(gen)
			if s != null:
				node.add_child(_settlement_ring(gen.position, island.radius, s))
	chunks.add_child(node)
	_loaded_chunks[chunk] = node


func _settlement_ring(pos: Vector2, radius: float, s: Settlement) -> Line2D:
	var ring := Line2D.new()
	ring.name = "Ring_" + Coord.key(s.coord)
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(pos + Vector2.from_angle(float(i) / 32.0 * TAU) * radius * 1.3)
	ring.points = pts
	ring.closed = true
	ring.width = 3.0
	ring.default_color = OWN_COLOR if s.is_own else FOREIGN_COLOR
	return ring


func _rebuild_labels() -> void:
	for c in labels.get_children():
		c.queue_free()
	for s: Settlement in GameState.settlements.values():
		var island := GameState.island_at(s.coord)
		var radius := island.radius if island != null else 80.0
		var label := Label.new()
		label.text = "%s\n%s" % [s.name, "Ty" if s.is_own else "gracz %d" % s.owner_id]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(240, 56)
		label.position = WorldGrid.cell_to_world(s.coord) + Vector2(-120, radius * 1.3 + 4)
		label.add_theme_font_size_override("font_size", 20)
		label.modulate = OWN_COLOR if s.is_own else FOREIGN_COLOR
		labels.add_child(label)


func _on_settlement_updated(coord: Vector2i) -> void:
	var chunk := WorldGrid.chunk_of(coord)
	if _loaded_chunks.has(chunk):
		_loaded_chunks[chunk].queue_free()
		_loaded_chunks.erase(chunk)
		_pending.append(chunk)
	_rebuild_labels()


func _on_tapped(world_pos: Vector2) -> void:
	var cell := WorldGrid.world_to_cell(world_pos)
	var island := GameState.island_at(cell)
	if island == null:
		return
	var local := world_pos - WorldGrid.cell_to_world(cell)
	if local.length() > island.radius * 1.1:
		return
	GameState.inspect(cell)
	var s := GameState.settlement_at(cell)
	if s != null and s.is_own:
		GameState.set_active_settlement(cell)
	SceneManager.show_island_detail()
```

Utwórz `scenes/views/WorldMap.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scenes/views/WorldMap.gd" id="1"]
[ext_resource type="Script" path="res://scenes/views/Water.gd" id="2"]
[ext_resource type="Script" path="res://scenes/procedural/FleetRenderer.gd" id="3"]
[ext_resource type="Script" path="res://scenes/views/MapCamera.gd" id="4"]

[node name="WorldMap" type="Node2D"]
script = ExtResource("1")

[node name="Background" type="CanvasLayer" parent="."]
layer = -100

[node name="Sea" type="ColorRect" parent="Background"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.09, 0.32, 0.5, 1)

[node name="Water" type="Node2D" parent="."]
script = ExtResource("2")

[node name="Chunks" type="Node2D" parent="."]

[node name="Labels" type="Node2D" parent="."]

[node name="Fleets" type="Node2D" parent="."]
script = ExtResource("3")

[node name="Camera" type="Camera2D" parent="."]
script = ExtResource("4")
```

- [ ] **Krok 6: Commit**

```bash
git add scenes/views/MapCamera.gd scenes/views/Water.gd scenes/views/WorldMap.gd scenes/views/WorldMap.tscn test/scenes/map_camera_test.gd
git commit -m "Add world map view with touch camera, water grid and chunked islands"
```

---

### Task 12: IslandDetail i BuildingMenu

**Files:**
- Create: `scenes/ui/BuildingMenu.gd`, `scenes/ui/BuildingMenu.tscn`, `scenes/views/IslandDetail.gd`, `scenes/views/IslandDetail.tscn`

**Interfaces:**
- Consumes: `IslandGenerator`, `Island`, `Settlement`, `Biome`, `Buildings`, `ResourceTypes`, `Coord`, autoloady `GameState`, `SceneManager` (`show_world_map()`).
- Produces: `BuildingMenu` (`PanelContainer`) z sygnałem `upgrade_requested(building: int)` i metodą `open(building: Buildings.Type, level: int)`.
- Produces: `IslandDetail.tscn` z węzłami `Generator`, `Camera`, `UI/BackButton`, `UI/InfoPanel/Info`, `UI/BuildingMenu`; skrypt reaguje na `GameState.inspected_island_changed`.

Trzy tryby wg `GameState.settlement_at(inspected_coord)`: własna osada (sloty i menu budynku), cudza osada (tylko dane publiczne), wyspa niczyja (znalezisko). Tap na slot: `InputEventScreenTouch` (puszczenie) → współrzędne świata przez odwrotność `get_canvas_transform()` → `generator.slot_at()`.

- [ ] **Krok 1: Zaimplementuj BuildingMenu**

Utwórz `scenes/ui/BuildingMenu.gd`:

```gdscript
class_name BuildingMenu
extends PanelContainer

## Panel budynku: nazwa, poziom, "Ulepsz". Bez logiki; emituje upgrade_requested.

signal upgrade_requested(building: int)

@onready var title: Label = $VBox/Title
@onready var level_label: Label = $VBox/Level
@onready var upgrade_button: Button = $VBox/Upgrade
@onready var close_button: Button = $VBox/Close

var _building: int = -1


func _ready() -> void:
	hide()
	upgrade_button.pressed.connect(_on_upgrade)
	close_button.pressed.connect(hide)


func open(building: Buildings.Type, level: int) -> void:
	_building = building
	title.text = Buildings.label(building)
	level_label.text = "Poziom %d" % level
	upgrade_button.text = "Ulepsz do %d" % (level + 1)
	show()


func _on_upgrade() -> void:
	upgrade_requested.emit(_building)
```

Utwórz `scenes/ui/BuildingMenu.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/BuildingMenu.gd" id="1"]

[node name="BuildingMenu" type="PanelContainer"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -220.0
offset_top = -140.0
offset_right = 220.0
offset_bottom = 140.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 2

[node name="Title" type="Label" parent="VBox"]
layout_mode = 2
text = "Budynek"
horizontal_alignment = 1

[node name="Level" type="Label" parent="VBox"]
layout_mode = 2
text = "Poziom 0"
horizontal_alignment = 1

[node name="Upgrade" type="Button" parent="VBox"]
layout_mode = 2
text = "Ulepsz"

[node name="Close" type="Button" parent="VBox"]
layout_mode = 2
text = "Zamknij"
```

- [ ] **Krok 2: Zaimplementuj IslandDetail**

Utwórz `scenes/views/IslandDetail.gd`:

```gdscript
extends Node2D

## Trzy tryby wg stanu oglądanej wyspy: własna osada (sloty), cudza osada (dane publiczne), wyspa niczyja (znalezisko).

const DETAIL_RADIUS := 400.0

@onready var generator: IslandGenerator = $Generator
@onready var back_button: Button = $UI/BackButton
@onready var info: Label = $UI/InfoPanel/Info
@onready var building_menu: BuildingMenu = $UI/BuildingMenu

var _settlement: Settlement = null


func _ready() -> void:
	back_button.pressed.connect(SceneManager.show_world_map)
	building_menu.upgrade_requested.connect(_on_upgrade_requested)
	GameState.inspected_island_changed.connect(_show)
	GameState.settlement_updated.connect(_on_settlement_updated)
	_show(GameState.inspected_coord)


func _show(coord: Vector2i) -> void:
	var island := GameState.island_at(coord)
	if island == null:
		info.text = "Morze"
		return
	_settlement = GameState.settlement_at(coord)
	generator.seed_val = island.seed_val
	generator.biome = island.biome
	generator.radius = DETAIL_RADIUS
	generator.deposit = island.deposit
	generator.show_deposit = _settlement == null
	generator.settlement = _settlement
	generator.show_slots = _settlement != null and _settlement.is_own
	generator.build()
	info.text = _describe(island, _settlement)


func _describe(island: Island, s: Settlement) -> String:
	var where := "(%d, %d) · %s" % [island.coord.x, island.coord.y, Biome.key(island.biome)]
	if s == null:
		if island.has_deposit():
			var parts: Array[String] = []
			for k in island.deposit:
				parts.append("%s %d" % [ResourceTypes.LABELS[k], int(island.deposit[k])])
			return "Wyspa niczyja %s\nZnalezisko: %s" % [where, ", ".join(parts)]
		return "Wyspa niczyja %s\nBrak znaleziska" % where
	if s.is_own:
		return "%s %s\nLudność %d / %d · Magazyn %d" % [s.name, where, s.population, s.population_max, int(s.capacity)]
	return "%s %s\nWłaściciel: gracz %d" % [s.name, where, s.owner_id]


func _on_settlement_updated(coord: Vector2i) -> void:
	if coord == GameState.inspected_coord:
		_show(coord)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or event.pressed or not generator.show_slots:
		return
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
	var slot := generator.slot_at(generator.to_local(world_pos))
	if slot >= 0:
		building_menu.open(slot, _settlement.level(slot))


func _on_upgrade_requested(building: int) -> void:
	print("upgrade_requested: %s w %s" % [Buildings.key(building), Coord.key(GameState.inspected_coord)])
```

Utwórz `scenes/views/IslandDetail.tscn`:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scenes/views/IslandDetail.gd" id="1"]
[ext_resource type="Script" path="res://scenes/procedural/IslandGenerator.gd" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/BuildingMenu.tscn" id="3"]

[node name="IslandDetail" type="Node2D"]
script = ExtResource("1")

[node name="Background" type="CanvasLayer" parent="."]
layer = -100

[node name="Sea" type="ColorRect" parent="Background"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.09, 0.32, 0.5, 1)

[node name="Generator" type="Node2D" parent="."]
script = ExtResource("2")

[node name="Camera" type="Camera2D" parent="."]

[node name="UI" type="CanvasLayer" parent="."]
layer = 1

[node name="BackButton" type="Button" parent="UI"]
offset_left = 16.0
offset_top = 112.0
offset_right = 200.0
offset_bottom = 172.0
text = "← Mapa"

[node name="InfoPanel" type="PanelContainer" parent="UI"]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -160.0
grow_horizontal = 2
grow_vertical = 0

[node name="Info" type="Label" parent="UI/InfoPanel"]
layout_mode = 2
text = "-"
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 3

[node name="BuildingMenu" parent="UI" instance=ExtResource("3")]
```

- [ ] **Krok 3: Sprawdź, że sceny się parsują**

Uruchom: `./run_tests.sh test/scenes/`
Oczekiwane: brak `SCRIPT ERROR` w wyjściu i `Exit code: 0`. Import projektu (pierwsza linia `run_tests.sh`) wczytuje wszystkie `.tscn`, więc błąd składni sceny pojawiłby się tutaj.

- [ ] **Krok 4: Commit**

```bash
git add scenes/ui/BuildingMenu.gd scenes/ui/BuildingMenu.tscn scenes/views/IslandDetail.gd scenes/views/IslandDetail.tscn
git commit -m "Add island detail view with three modes and building menu"
```

---

### Task 13: HUD

**Files:**
- Create: `scenes/ui/HUD.gd`, `scenes/ui/HUD.tscn`

**Interfaces:**
- Consumes: `Settlement.current_resources(now)`, `Settlement.produces(r)`, `TimeUtil.now()`, `TimeUtil.format_amount()`, `ResourceTypes`, autoload `GameState` (`active_settlement`, sygnały `active_settlement_changed`, `settlement_updated`).
- Produces: `HUD.tscn` (`CanvasLayer`, `layer = 10`) z węzłami `TopBar/HBox/Chips`, `TopBar/HBox/Population`, `TopBar/HBox/SettlementName`; pola `name_label`, `population_label`, `_labels` (używane przez smoke test).

HUD nie liczy nic sam: co klatkę woła `current_resources(TimeUtil.now())` i wpisuje `floor()` do labeli. Poniżej 700 px szerokości viewportu używa formatu `1.2k`. Chipy zasobów, których osada nie produkuje, są przyciemnione. Pasek jest przesuwany o safe area (notch).

- [ ] **Krok 1: Zaimplementuj HUD**

Utwórz `scenes/ui/HUD.gd`:

```gdscript
extends CanvasLayer

## Pasek zasobów osady aktywnej. Nie liczy nic sam: woła Settlement.current_resources(TimeUtil.now()).

const BAR_HEIGHT := 96.0
const NARROW_WIDTH := 700.0
const ICON_SIZE := 24.0
const DIMMED := 0.45

@onready var top_bar: PanelContainer = $TopBar
@onready var chips: HBoxContainer = $TopBar/HBox/Chips
@onready var population_label: Label = $TopBar/HBox/Population
@onready var name_label: Label = $TopBar/HBox/SettlementName

var _settlement: Settlement = null
## zasób -> Label
var _labels: Dictionary = {}
## zasób -> HBoxContainer (cały chip)
var _chips: Dictionary = {}


func _ready() -> void:
	_build_chips()
	GameState.active_settlement_changed.connect(_on_active_changed)
	GameState.settlement_updated.connect(_on_settlement_updated)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_on_active_changed()


func _build_chips() -> void:
	for r in ResourceTypes.ALL:
		var chip := HBoxContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := ColorRect.new()
		icon.color = ResourceTypes.COLORS[r]
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(icon)
		var label := Label.new()
		label.text = "0"
		chip.add_child(label)
		chips.add_child(chip)
		_labels[r] = label
		_chips[r] = chip


func _on_active_changed() -> void:
	_settlement = GameState.active_settlement
	if _settlement == null:
		name_label.text = "-"
		return
	name_label.text = "%s (%d, %d)" % [_settlement.name, _settlement.coord.x, _settlement.coord.y]
	_dim_chips()


func _on_settlement_updated(coord: Vector2i) -> void:
	if _settlement != null and coord == _settlement.coord:
		_on_active_changed()


func _process(_delta: float) -> void:
	if _settlement == null:
		return
	var current := _settlement.current_resources(TimeUtil.now())
	var narrow := get_viewport().get_visible_rect().size.x < NARROW_WIDTH
	for r in ResourceTypes.ALL:
		_labels[r].text = TimeUtil.format_amount(current[r]) if narrow else "%d" % int(floorf(current[r]))
	population_label.text = "%d / %d" % [_settlement.population, _settlement.population_max]


func _dim_chips() -> void:
	for r in ResourceTypes.ALL:
		_chips[r].modulate.a = 1.0 if _settlement.produces(r) else DIMMED


## Przesuwa pasek pod notch; safe area jest w pikselach okna, viewport w pikselach canvasu.
func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var vis := get_viewport().get_visible_rect().size
	var scale := vis.y / maxf(float(win.y), 1.0)
	var top := float(safe.position.y) * scale
	top_bar.offset_top = top
	top_bar.offset_bottom = top + BAR_HEIGHT
```

Utwórz `scenes/ui/HUD.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/HUD.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
layer = 10
script = ExtResource("1")

[node name="TopBar" type="PanelContainer" parent="."]
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 96.0
grow_horizontal = 2

[node name="HBox" type="HBoxContainer" parent="TopBar"]
layout_mode = 2

[node name="Chips" type="HBoxContainer" parent="TopBar/HBox"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Population" type="Label" parent="TopBar/HBox"]
layout_mode = 2
text = "0 / 0"

[node name="SettlementName" type="Label" parent="TopBar/HBox"]
layout_mode = 2
text = "-"
```

- [ ] **Krok 2: Sprawdź, że scena się parsuje**

Uruchom: `./run_tests.sh test/scenes/`
Oczekiwane: brak `SCRIPT ERROR`, `Exit code: 0`.

- [ ] **Krok 3: Commit**

```bash
git add scenes/ui/HUD.gd scenes/ui/HUD.tscn
git commit -m "Add HUD with lazily evaluated resource counters"
```

---

### Task 14: ApiClient, SceneManager, Main i smoke test scen

**Files:**
- Create: `scenes/autoload/ApiClient.gd`, `scenes/autoload/SceneManager.gd`, `scenes/views/Main.gd`, `scenes/views/Main.tscn`
- Create: `tools/smoke_probe.gd`, `tools/Smoke.tscn`, `run_smoke.sh`

**Interfaces:**
- Consumes: wszystko powyżej.
- Produces (autoload `ApiClient`): `provider: ApiProvider`, `load_initial()`, `resync()`, sygnały `request_failed(reason: String)`, `synced`; `Timer` resync co 60 s.
- Produces (autoload `SceneManager`): `register_container(node)`, `show_world_map()`, `show_island_detail()`, `current_view: String`, stałe `VIEW_WORLD_MAP`, `VIEW_ISLAND_DETAIL`, sygnał `view_changed(view_path)`.
- Produces: `./run_smoke.sh` (kod wyjścia 0 = przepływ mapa → detal w trzech trybach → mapa działa).

Przepływ startu: `Main._ready()` → `SceneManager.register_container()` → `ApiClient.load_initial()` → `GameState.apply_*` → `finish_loading()` → `state_loaded` → `SceneManager.show_world_map()`.

- [ ] **Krok 1: Zaimplementuj autoloady**

Utwórz `scenes/autoload/ApiClient.gd`:

```gdscript
extends Node

signal request_failed(reason: String)
signal synced

const RESYNC_SECONDS := 60.0

var provider: ApiProvider
var _timer: Timer


func _ready() -> void:
	var use_mock: bool = ProjectSettings.get_setting("islanders/api/use_mock", true)
	if use_mock:
		provider = MockProvider.new()
	else:
		var url: String = ProjectSettings.get_setting("islanders/api/base_url", "http://localhost:3000")
		provider = HttpProvider.new(self, url)
	_timer = Timer.new()
	_timer.wait_time = RESYNC_SECONDS
	_timer.timeout.connect(resync)
	add_child(_timer)


func load_initial() -> void:
	var w: Dictionary = await provider.fetch_world()
	if w.is_empty():
		request_failed.emit("world")
		return
	if w.has("serverTime"):
		TimeUtil.set_server_time(TimeUtil.parse_iso8601(str(w["serverTime"])))
	GameState.apply_world(w)
	GameState.apply_settlements(await provider.fetch_settlements())
	GameState.apply_fleets(await provider.fetch_fleets())
	GameState.finish_loading()
	_timer.start()


func resync() -> void:
	var settlements: Array = await provider.fetch_settlements()
	GameState.apply_settlements(settlements)
	GameState.apply_fleets(await provider.fetch_fleets())
	synced.emit()
```

Utwórz `scenes/autoload/SceneManager.gd`:

```gdscript
extends Node

signal view_changed(view_path: String)

const VIEW_WORLD_MAP := "res://scenes/views/WorldMap.tscn"
const VIEW_ISLAND_DETAIL := "res://scenes/views/IslandDetail.tscn"

var current_view: String = ""
var _container: Node = null
var _current: Node = null


func register_container(container: Node) -> void:
	_container = container


func show_world_map() -> void:
	_swap(VIEW_WORLD_MAP)


func show_island_detail() -> void:
	_swap(VIEW_ISLAND_DETAIL)


func _swap(path: String) -> void:
	if _container == null:
		push_error("SceneManager: brak kontenera widoków (register_container)")
		return
	if _current != null:
		_current.queue_free()
	var scene: PackedScene = load(path)
	_current = scene.instantiate()
	_container.add_child(_current)
	current_view = path
	view_changed.emit(path)
```

- [ ] **Krok 2: Zaimplementuj Main**

Utwórz `scenes/views/Main.gd`:

```gdscript
extends Node

@onready var view_container: Node = $ViewContainer


func _ready() -> void:
	SceneManager.register_container(view_container)
	GameState.state_loaded.connect(SceneManager.show_world_map, CONNECT_ONE_SHOT)
	ApiClient.request_failed.connect(func(reason: String) -> void: push_error("Ładowanie nieudane: %s" % reason))
	ApiClient.load_initial()
```

Utwórz `scenes/views/Main.tscn`:

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/views/Main.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="2"]

[node name="Main" type="Node"]
script = ExtResource("1")

[node name="ViewContainer" type="Node" parent="."]

[node name="HUD" parent="." instance=ExtResource("2")]
```

- [ ] **Krok 3: Napisz smoke test scen**

Utwórz `tools/smoke_probe.gd`:

```gdscript
extends Node

## Smoke test scen: uruchamia Main, klika osadę domową, przechodzi przez trzy tryby detalu i wraca.
## Użycie: ./run_smoke.sh  (kończy się kodem 0 przy sukcesie, 1 przy błędzie)

const MAIN := preload("res://scenes/views/Main.tscn")

var _frame := 0
var _failed := false


func _ready() -> void:
	add_child(MAIN.instantiate())


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_failed = true


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		20:
			_check(GameState.world != null and GameState.world.id == "w1", "świat załadowany")
			_check(GameState.settlements.size() == 3, "3 osady")
			_check(GameState.fleets.size() == 3, "3 floty")
			_check(GameState.active_settlement != null and GameState.active_settlement.name == "Koralowa", "osada domowa aktywna")
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "widok mapy")
			var map := get_node_or_null("Main/ViewContainer/WorldMap")
			_check(map != null and map.get_node("Chunks").get_child_count() > 0, "chunki załadowane")
			_check(map != null and map.get_node("Labels").get_child_count() == 3, "3 etykiety osad")
			if map:
				map._on_tapped(WorldGrid.cell_to_world(Vector2i(103, 100)))
		30:
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "tap otwiera detal")
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and det.get_node("Generator").show_slots, "własna osada ma sloty")
			_check(det != null and det.get_node("Generator")._slot_positions.size() == 6, "6 slotów")
			GameState.inspect(Vector2i(95, 100))
		35:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and not det.get_node("Generator").show_slots, "cudza osada bez slotów")
			_check(det != null and det.get_node("UI/InfoPanel/Info").text.contains("gracz 9"), "cudza osada pokazuje właściciela")
			GameState.inspect(Vector2i(95, 98))
		40:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and det.get_node("Generator").show_deposit, "wyspa niczyja pokazuje znalezisko")
			var hud := get_node("Main/HUD")
			_check(hud.name_label.text.begins_with("Koralowa"), "HUD pokazuje osadę aktywną")
			_check(hud.population_label.text == "42 / 120", "HUD pokazuje populację")
			ApiClient.resync()
		45:
			_check(GameState.settlements.size() == 3, "resync zachowuje osady")
			SceneManager.show_world_map()
		50:
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "powrót do mapy")
			print("SMOKE %s" % ("FAILED" if _failed else "PASSED"))
			get_tree().quit(1 if _failed else 0)
```

Utwórz `tools/Smoke.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/smoke_probe.gd" id="1"]

[node name="Smoke" type="Node"]
script = ExtResource("1")
```

Utwórz `run_smoke.sh`:

```sh
#!/bin/sh
# Headless smoke test scen: ładuje Main przez tools/Smoke.tscn i sprawdza przepływ mapa -> detal -> mapa.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . res://tools/Smoke.tscn 2>&1 | grep -E "^(OK|FAIL|SMOKE)|SCRIPT ERROR|ERROR:"
```

```bash
chmod +x run_smoke.sh
```

- [ ] **Krok 4: Uruchom smoke test**

Uruchom: `./run_smoke.sh; echo exit=$?`
Oczekiwane: 17 linii `OK`, linia `SMOKE PASSED`, `exit=0`, brak `SCRIPT ERROR`. Linie `ERROR:` z `push_error` nie powinny się pojawić; jeśli widzisz `osada na (x, y), a WorldGrid uznaje tę komórkę za morze`, fixtures rozjechały się z `WorldGrid` (patrz Task 5).

- [ ] **Krok 5: Uruchom komplet testów**

Uruchom: `./run_tests.sh test/`
Oczekiwane: `Overall Summary: ... 0 errors | 0 failures`, `Exit code: 0`

Oczekiwana liczba: 86 przypadków testowych, 13 suit.

- [ ] **Krok 6: Weryfikacja ręczna w Godocie**

Uruchom projekt (F5 w edytorze albo `"$GODOT" --path .`) i sprawdź w oknie 540×960:
1. Mapa startuje wycentrowana na osadzie „Koralowa”; widać wyspy z żółtym (własne) i jasnym (cudza) pierścieniem oraz etykiety.
2. Przeciąganie LPM przesuwa mapę z inercją; scroll myszy zoomuje do kursora w zakresie 0,25–2,0; przy zoomie poniżej 0,6 znikają etykiety.
3. Żółta przerywana linia z trójkątem i odliczaniem `EXP mm:ss` to własna wyprawa; czerwona `ATT` to nadchodzący atak.
4. Klik (bez przeciągania) na „Koralowa” otwiera detal: 6 sześciokątnych slotów, ratusz w środku, stocznia przy zatoce; klik na slot otwiera panel z „Ulepsz do N”, „Ulepsz” wypisuje `upgrade_requested` w konsoli.
5. „← Mapa” wraca; klik na „Szara Skała” pokazuje właściciela bez slotów; klik na wyspę bez pierścienia pokazuje znalezisko (romb przy brzegu).
6. HUD u góry: 5 chipów, drewno i jedzenie rosną co sekundę o ułamki, kamień/żelazo/siarka przyciemnione, populacja `42 / 120`.
7. Zmień rozmiar okna na poziomy (np. 960×540): pasek HUD rozciąga się, liczby przechodzą w format `1.2k` gdy szerokość viewportu spadnie poniżej 700 px.

- [ ] **Krok 7: Commit**

```bash
git add scenes/autoload/ApiClient.gd scenes/autoload/SceneManager.gd scenes/views/Main.gd scenes/views/Main.tscn tools run_smoke.sh
git commit -m "Wire autoloads and Main scene, add headless scene smoke test"
```

---

## Po zakończeniu

- Uruchom `./run_tests.sh && ./run_smoke.sh` jako ostateczną weryfikację przed zgłoszeniem ukończenia.
- Poza zakresem tego planu (spec, sekcja 1): wysyłanie flot z UI, logika ulepszania, wyprawy i kolonizacja jako akcje, prawdziwe endpointy w NestJS. Backend powinien dostać port `WorldGrid.hash_cell` i `island_at` z identycznymi stałymi (ADR 0001).
