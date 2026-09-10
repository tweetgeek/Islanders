# Islanders UI v2 – korekty po przeglądzie: plan implementacji

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zmniejszyć górny pasek do dwóch wierszy, zagęścić odstępy jednym pokrętłem, rozsunąć wyspy i rozbić siatkę przesunięciem, które staje się częścią kontraktu i wyznacza odległość podróży, sprawić, żeby tapnięcie wyspy zawsze tylko ją oglądało, i pokazywać pseudonimy zamiast identyfikatorów kont.

**Architecture:** Motyw dostaje drugą funkcję skalującą `gap()` dla przestrzeni między elementami, niezależną od `px()` dla rozmiarów. Położenie wyspy w obrębie komórki trafia do `WorldGrid` jako czysta funkcja kontraktu (ułamki komórki), z której rendering liczy piksele, a nawigacja odległości. Arkusz oglądanej wyspy zyskuje trzeci tryb dla własnej osady, a jedyną drogą zmiany osady aktywnej staje się jawna akcja w arkuszu.

**Tech Stack:** Godot 4.8 dev4 (GL Compatibility), GDScript 2.0, gdUnit4 (`./run_tests.sh`), smoke test scen (`./run_smoke.sh`), sonda wizualna `tools/capture_probe.gd`, generator kontraktu `./run_parity.sh`, Python 3 do niezależnej weryfikacji kontraktu.

**Spec:** `docs/superpowers/specs/2026-09-09-islanders-ui-v2-polish-design.md`. Decyzje architektoniczne: `docs/adr/0003-island-position-drives-travel-distance.md` i `docs/adr/0001-deterministic-world-geography.md`, Załącznik, punkt 8. Glosariusz: `CONTEXT.md`.

## Global Constraints

- Praca w osobnym worktree `.worktree/ui-polish` na gałęzi `feat/ui-polish` od `fix/hud-settlement-name` (Task 0). Wszystkie komendy uruchamiane z katalogu worktree.
- Godot: `/Applications/Godot.app/Contents/MacOS/Godot`. Viewport 1080 × 1920, `canvas_items`, `aspect = expand`.
- Każdy wymiar z projektu przechodzi przez `MedievalTheme`: **przestrzeń między rzeczami i wokół nich przez `gap()`, rozmiar samej rzeczy przez `px()`**. Rozmiary fontów, boki ikon, wcięcia ikon w przyciskach, wysokości przycisków, promienie, obramowania, cienie i przesunięcia odznak zostają przy `px()`. Geometria świata (`SlotPlaque`, etykiety i pierścienie na mapie) nie przechodzi przez żadną z nich.
- `DENSITY = 0.7`, `OFFSET_RANGE = 0.13`, `CELL_SIZE = 448`, `ZOOM_MIN = 0.15` — dokładnie te wartości; strojenie po przeglądzie wizualnym to osobna decyzja człowieka, nie część tego planu.
- Wzór przesunięcia wyspy jest kontraktem z ADR 0001, punkt 8, i musi być przepisany dosłownie: sole `(13, 17)` i `(19, 23)`, mapowanie `* 2.0 - 1.0`, mnożnik `OFFSET_RANGE`. Żadne dotychczasowe pole `contract/world-parity.json` nie może zmienić wartości.
- Ikony zostają glifami rysowanymi w `_draw()`; zasada o zewnętrznych grafikach została zniesiona, ale przejście na grafiki nie jest częścią tej fali.
- Tapnięcie wyspy na mapie nigdy nie zmienia osady aktywnej. Zmienia ją wyłącznie akcja w arkuszu oglądanej wyspy (glosariusz: **Active Settlement**).
- Innym graczom pokazujemy wyłącznie pseudonim (`ownerName`), nigdy numeryczny `ownerId`. Własna osada pokazuje „Ty”.
- Komentarze w kodzie po polsku, identyfikatory po angielsku. Teksty przycisków wielkimi literami, jak w istniejących arkuszach.
- Komórki świata w testach i w smoke teście pochodzą wyłącznie z `test/FixtureCells.gd`.
- Pliki `.uid` i `.import` są śledzone w git i trafiają do commitów.
- Wyjście testów ma być czyste: bez ostrzeżeń i bez `SCRIPT ERROR`.
- Znany kaprys gdUnit: uruchamiacz przerywa zestaw na pierwszym nieudanym teście. Dowód RED dla kilku nowych testów w jednym pliku zbiera się po jednym teście naraz, na przykład tymczasowo wyłączając pozostałe przez prefiks nazwy `_disabled_`, i przywraca je przed commitem.
- Testy scen mierzące geometrię (wysokość paska, szerokości etykiet) wołają `MedievalTheme.install()` w `before_test()`, żeby mierzyć konfigurację wysyłaną do gracza, a nie domyślny motyw silnika.
- Każdy commit kończy się stopką:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01TqfePPRx93prY96Z6atQZq
  ```

## Odstępstwa od specyfikacji, rozstrzygnięte przy planowaniu

1. **Populacja w widoku osady** trafia do nowego wiersza `StatusRow` w lewym dolnym rogu nad dokiem, razem z podpowiedzią: najpierw stała plakietka populacji, potem podpowiedź, która znika po pierwszym otwarciu budynku. To dosłowna realizacja „obok istniejącej podpowiedzi”, z podpowiedzią przeniesioną do wspólnego kontenera, żeby plakietka populacji nie przeskakiwała, gdy podpowiedź zniknie.
2. **Teksty akcji w arkuszu własnej osady** to „PRZEJDŹ DO OSADY” i „WRÓĆ DO OSADY”, wielkimi literami, bo tak piszą się wszystkie przyciski w arkuszach („ULEPSZ”, „ZAMKNIJ”).
3. **Brak pseudonimu w danych** daje tekst „nieznany gracz”, nigdy identyfikator. Wartość domyślna żyje w `Settlement.UNKNOWN_OWNER` i jest ustawiana przy parsowaniu, więc miejsca wyświetlania nie powielają logiki zapasowej.
4. **`Icon.into_button` dostaje opcjonalny kolor wycięcia z domyślnym `OAK`**, bo w tym projekcie każdy przycisk z ikoną ma dębowe tło (`ToolButton`). Samo `Icon` zostaje przy domyślnym `PARCHMENT`.
5. **Przesunięcie w pełnej precyzji: `WorldGrid.island_offset_xy() -> PackedFloat64Array`.** `Vector2` w tym buildzie trzyma float32 (sprawdzone: `Vector2(0.07367142999900071, 0).x` różni się o 3,5e-10), więc artefakt kontraktu i złote testy liczą się z tej funkcji; `island_offset`, `island_position` i `island_center` są jej widokiem float32 dla renderowania i nawigacji. Spec, sekcja 5.2, uzupełniony.
6. **Test prześwitu mierzy prawdziwe kontury.** Model „koło o promieniu `radius × 1,18`” ze specu okazał się błędny (kontur ma szum ±35 % i elipsę 0,8–1,2; zasięg wody w medianie 1,42 promienia). Test w Task 7 sprawdza wielokąty `Shallow` z `IslandGenerator`, a spec (5.2, 9) i ADR 0003 dostały dane z pomiaru: przy 448 px i ±0,13 zero nałożeń na ~14 000 par, najmniejszy prześwit ~52 px, pierwsze zetknięcie przy ~0,21.
7. **`GameState.world_seed()`** zwraca ziarno świata albo 0 bez świata. Trzy miejsca (mapa, rysowanie flot, arkusze) potrzebują tego samego zabezpieczenia, więc mieszka ono w jednym miejscu.
8. **Ikona powrotu na mapie to osobny Task 8**, bo przegląd może ją odrzucić niezależnie od geometrii mapy.

---

## Mapa plików

| Plik | Zmiana |
|---|---|
| `scenes/ui/MedievalTheme.gd` | `DENSITY`, `gap()`, marginesy `flat()` i separacje przez `gap()` |
| `scenes/ui/SheetStyle.gd`, `BuildingSheet.gd`, `FleetsSheet.gd`, `Dock.gd` | odstępy przez `gap()`; wycięcie ikon nagłówka, chipów i przycisków |
| `scenes/ui/HUD.tscn`, `HUD.gd` | dwa wiersze, bez awatara, złota i populacji; stan kart przez paletę |
| `scenes/views/IslandDetail.tscn`, `IslandDetail.gd` | `StatusRow` z populacją i podpowiedzią |
| `scenes/ui/Icon.gd` | `knockout`, nowa ikona kamienia |
| `scripts/core/WorldGrid.gd` | `OFFSET_RANGE`, `island_offset_xy`, `island_offset`, `island_position`, `island_center`, `CELL_SIZE = 448` |
| `scenes/autoload/GameState.gd` | `world_seed()` |
| `scenes/procedural/IslandGenerator.gd` | `shallow_outline()` dla testu prześwitu |
| `scripts/core/SeaNavigation.gd` | geometria na położeniach, `travel_time_between` |
| `scripts/core/Fleet.gd`, `Settlement.gd` | pozycje floty między środkami wysp; `owner_name` |
| `scenes/procedural/FleetRenderer.gd`, `scenes/ui/Sheets.gd`, `scenes/ui/FleetCard.gd` | konsumenci pozycji i pseudonimu; akcja wejścia do osady |
| `scenes/views/WorldMap.tscn`, `WorldMap.gd`, `MapCamera.gd` | wyspy, etykiety i trafianie od przesuniętego środka; ikona powrotu; `ZOOM_MIN` |
| `scenes/ui/InspectSheet.tscn`, `InspectSheet.gd` | tryb własnej osady z akcją |
| `tools/world_parity_dump.gd`, `contract/world-parity.json`, `contract/README.md` | `offsetX`, `offsetY`, `offsetRange` |
| `fixtures/settlements.json`, `fixtures/fleets.json` | `ownerName` |
| `tools/smoke_probe.gd`, `tools/capture_probe.gd` | nowy przepływ; wycinki nowego paska |
| dokumentacja | spec UI v2, spec szkieletu 4.2 i 4.3; dokument architektury po scaleniu, poza gałęzią |

Kolejność tasków: 0 worktree · 1 gęstość w motywie · 2 odstępy w arkuszach i na mapie · 3 pasek i populacja · 4 wycięcie ikon · 5 karty zasobów · 6 kontrakt położenia · 7 geometria mapy · 8 ikona powrotu · 9 tapnięcie ogląda · 10 pseudonim · 11 dokumentacja i przegląd. Każdy task zostawia zielone testy i smoke.

---

### Task 0: Worktree i stan wyjściowy

**Files:**
- Create: `.worktree/ui-polish/` (worktree git)

- [ ] **Step 1: Utwórz worktree**

```bash
cd /Users/sdawidziak/_TweetGeek/_Godot/Islanders/islanders
git worktree add .worktree/ui-polish -b feat/ui-polish fix/hud-settlement-name
cd .worktree/ui-polish
git log --oneline -3
```

Oczekiwane: wśród trzech ostatnich commitów jest `Add the UI v2 polish implementation plan` z gałęzi `fix/hud-settlement-name`. Katalog `.worktree/ui-v2` z poprzedniej fali zostaw w spokoju.

- [ ] **Step 2: Zaimportuj i uruchom testy bazowe**

```bash
./run_tests.sh
./run_smoke.sh
```

Oczekiwane: gdUnit bez błędów (191 testów), smoke kończy się `SMOKE PASSED` i kodem 0. Jeśli coś jest czerwone na starcie, zatrzymaj się i zgłoś, zamiast naprawiać po drodze.

---

### Task 1: Pokrętło gęstości w motywie

**Files:**
- Modify: `scenes/ui/MedievalTheme.gd:1-217`
- Test: `test/scenes/medieval_theme_test.gd`

**Interfaces:**
- Produces: `MedievalTheme.DENSITY: float = 0.7`, `static func gap(v: float) -> int` zwracające `int(roundf(v * SCALE * DENSITY))`. `flat()` bierze marginesy z `gap()`, promień i obramowanie z `px()`. Separacje `VBoxContainer` i `HBoxContainer` w motywie to `gap(9)` i `gap(6)`; `HSeparator` zostaje `px(1)`. Wciśnięty `Primary`: góra `gap(14) + px(3)`, dół `gap(14) - px(3)`.

- [ ] **Step 1: Przepisz test zasady i dodaj nowe testy**

W `test/scenes/medieval_theme_test.gd` zastąp `test_flat_scales_paddings` i dopisz na końcu pliku:

```gdscript
## Zasada podziału: marginesy wewnętrzne to przestrzeń między rzeczami (gap), promień
## i obramowanie to rozmiar samej rzeczy (px). Test przypina ją, żeby późniejsza zmiana
## nie przeniosła po cichu jednego do drugiego.
func test_flat_takes_margins_from_gap_and_shape_from_px() -> void:
	var sb := MedievalTheme.flat(Color.RED, Color.BLUE, 4, 1, 10, 8)
	assert_int(int(sb.content_margin_left)).is_equal(MedievalTheme.gap(10))
	assert_int(int(sb.content_margin_top)).is_equal(MedievalTheme.gap(8))
	assert_int(sb.corner_radius_top_left).is_equal(MedievalTheme.px(4))
	assert_int(sb.border_width_left).is_equal(MedievalTheme.px(1))


func test_gap_scales_by_scale_and_density() -> void:
	assert_int(MedievalTheme.gap(10.0)).is_equal(19)   # 10 × 2,77 × 0,7 = 19,39
	assert_int(MedievalTheme.gap(0.0)).is_equal(0)
	assert_float(MedievalTheme.DENSITY).is_greater(0.0)
	assert_float(MedievalTheme.DENSITY).is_less_equal(1.0)


func test_gap_never_exceeds_px() -> void:
	for v in range(1, 41):
		assert_int(MedievalTheme.gap(float(v))).is_less_equal(MedievalTheme.px(float(v)))


func test_container_separations_are_gaps() -> void:
	var t := MedievalTheme.build()
	assert_int(t.get_constant("separation", "VBoxContainer")).is_equal(MedievalTheme.gap(9))
	assert_int(t.get_constant("separation", "HBoxContainer")).is_equal(MedievalTheme.gap(6))
	# HSeparator to grubość linii, nie odstęp - zostaje przy px().
	assert_int(t.get_constant("separation", "HSeparator")).is_equal(MedievalTheme.px(1))


## Wciśnięty przycisk główny udaje zapadnięcie, przesuwając marginesy w przeciwne strony.
## Skok ma zostać trzema pikselami projektu niezależnie od gęstości, inaczej zagęszczenie
## zmniejszyłoby też skok i przycisk przestałby się widocznie wciskać.
func test_primary_press_travel_stays_three_design_pixels() -> void:
	var t := MedievalTheme.build()
	var normal: StyleBoxFlat = t.get_stylebox("normal", "Primary")
	var pressed: StyleBoxFlat = t.get_stylebox("pressed", "Primary")
	assert_int(int(normal.content_margin_top)).is_equal(MedievalTheme.gap(14))
	assert_int(int(pressed.content_margin_top - normal.content_margin_top)).is_equal(MedievalTheme.px(3))
	assert_int(int(normal.content_margin_bottom - pressed.content_margin_bottom)).is_equal(MedievalTheme.px(3))
```

- [ ] **Step 2: Uruchom, oczekuj porażki**

```bash
./run_tests.sh test/scenes/medieval_theme_test.gd
```

Oczekiwane: błąd parsowania, bo `MedievalTheme.gap` i `MedievalTheme.DENSITY` nie istnieją.

- [ ] **Step 3: Implementacja w `scenes/ui/MedievalTheme.gd`**

Zmień komentarz nagłówkowy (linie 4-6) na:

```gdscript
## Motyw „Chart & Timber”: dębowy chrome, mosiężne linie, pergaminowe karty.
## Morze (tło Main) jest jedyną ciemną powierzchnią; UI leży na nim jak drewno i papier.
## Wymiary z projektu (viewport 390 px) przechodzą przez px(), bo nasz viewport ma 1080 px;
## przestrzeń między elementami i wokół nich przechodzi przez gap(), które dokłada gęstość.
```

Pod `const SCALE := 2.77` dodaj:

```gdscript
## Gęstość odstępów: mnożnik wyłącznie dla przestrzeni między elementami i wokół nich (gap()),
## niezależny od SCALE. Rozmiary tekstu, ikon i przycisków zostają przy px().
const DENSITY := 0.7
```

Pod funkcją `px()` dodaj:

```gdscript
## Odstęp: przestrzeń między elementami i wokół nich. Skalowana dodatkowo gęstością,
## żeby dało się zagęścić interfejs bez zmniejszania tekstu i ikon.
static func gap(v: float) -> int:
	return int(roundf(v * SCALE * DENSITY))
```

W `flat()` zamień cztery linie marginesów na `gap()` i dodaj komentarz nad funkcją:

```gdscript
## Marginesy wewnętrzne to odstęp (gap), promień i obramowanie to rozmiar (px).
static func flat(bg: Color, border: Color, radius: int, border_width: int = 1,
		pad_h: int = 10, pad_v: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(px(radius))
	sb.border_color = border
	sb.set_border_width_all(px(border_width))
	sb.content_margin_left = gap(pad_h)
	sb.content_margin_right = gap(pad_h)
	sb.content_margin_top = gap(pad_v)
	sb.content_margin_bottom = gap(pad_v)
	sb.anti_aliasing = true
	return sb
```

W `build()` zamień dwie linie wciśniętego `Primary`:

```gdscript
	prim_down.content_margin_top = gap(14) + px(3)      # skok o 3 px projektu w dół, cień znika
	prim_down.content_margin_bottom = gap(14) - px(3)
```

oraz dwie separacje kontenerów:

```gdscript
	t.set_constant("separation", "VBoxContainer", gap(9))
	t.set_constant("separation", "HBoxContainer", gap(6))
```

`t.set_constant("separation", "HSeparator", px(1))` zostaje bez zmian.

- [ ] **Step 4: Uruchom test motywu i cały zestaw**

```bash
./run_tests.sh test/scenes/medieval_theme_test.gd
./run_tests.sh
./run_smoke.sh
```

Oczekiwane: wszystko zielone. Jeśli padnie test scen sprawdzający szerokości etykiet albo wysokości arkuszy, zatrzymaj się i zgłoś — zmniejszenie marginesów nie powinno nikogo zawężać.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/MedievalTheme.gd test/scenes/medieval_theme_test.gd
git commit -m "Add a density knob so spacing tightens without shrinking text"
```

(z pełną stopką z Global Constraints)

---

### Task 2: Odstępy w arkuszach, doku, widoku osady i na mapie przez `gap()`

**Files:**
- Modify: `scenes/ui/SheetStyle.gd:19-21`, `scenes/ui/BuildingSheet.gd:40`, `scenes/ui/FleetsSheet.gd:27`, `scenes/ui/Dock.gd:79`, `scenes/views/IslandDetail.gd:7-9,68-71`, `scenes/views/WorldMap.gd:156,174`
- Test: `test/scenes/sheets_test.gd`, `test/scenes/dock_test.gd`, `test/scenes/world_map_test.gd`

**Interfaces:**
- Consumes: `MedievalTheme.gap(v: float) -> int` z Task 1.
- Produces: `IslandDetail.DOCK_TOOL := 46.0`, `IslandDetail.DOCK_GAP := 24.0` w miejsce `DOCK_CLEARANCE`. Pasek HUD nie jest tu ruszany — Task 3 przepisuje go w całości od razu na `gap()`.

- [ ] **Step 1: Testy wskazujące, że każde miejsce używa odstępu**

Dopisz do `test/scenes/sheets_test.gd`:

```gdscript
func test_sheet_margins_and_body_separation_are_gaps() -> void:
	var s := _sheets()
	var margin: MarginContainer = s.building_sheet.get_node("SheetMargin")
	assert_int(margin.get_theme_constant("margin_left")).is_equal(MedievalTheme.gap(SheetStyle.MARGIN))
	var body: Control = margin.get_node("Body")
	assert_int(body.get_theme_constant("separation")).is_equal(MedievalTheme.gap(11))
```

Dopisz do `test/scenes/dock_test.gd`:

```gdscript
func test_dock_buttons_sit_one_gap_from_the_edge() -> void:
	var d := _dock()
	await await_idle_frame()
	assert_float(d.fleets_button.position.x).is_equal(float(MedievalTheme.gap(d.MARGIN)))
```

Dopisz do `test/scenes/world_map_test.gd`:

```gdscript
func test_map_ui_margins_are_gaps() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	assert_float(world_map.back_plaque.position.x).is_equal(float(MedievalTheme.gap(world_map.UI_MARGIN)))
	assert_int(world_map.zoom_controls.get_theme_constant("separation")).is_equal(MedievalTheme.gap(8))
```

- [ ] **Step 2: Uruchom po jednym, oczekuj porażek**

```bash
./run_tests.sh test/scenes/sheets_test.gd
./run_tests.sh test/scenes/dock_test.gd
./run_tests.sh test/scenes/world_map_test.gd
```

Oczekiwane: każdy nowy test pada, bo miejsca używają jeszcze `px()`. Zbierz dowód RED dla każdego z trzech plików.

- [ ] **Step 3: Implementacja**

`scenes/ui/SheetStyle.gd`, w `apply_common`:

```gdscript
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MedievalTheme.gap(MARGIN))
	(margin.get_node("Body") as Control).add_theme_constant_override("separation", MedievalTheme.gap(11))
```

`scenes/ui/BuildingSheet.gd:40`:

```gdscript
	cost_grid.add_theme_constant_override("h_separation", MedievalTheme.gap(6))
```

`scenes/ui/FleetsSheet.gd:27`:

```gdscript
	list.add_theme_constant_override("separation", MedievalTheme.gap(10))
```

`scenes/ui/Dock.gd`, w `_layout()`:

```gdscript
	var m := MedievalTheme.gap(MARGIN)
```

Przesunięcia odznaki (`-px(14)`, `-px(8)`) i wcięcia ikon (`px(10)`) zostają przy `px()`: to rozmiar i położenie glifu, nie odstęp.

`scenes/views/IslandDetail.gd` — zamień stałą `DOCK_CLEARANCE` na dwie:

```gdscript
## Przycisk docku (rozmiar) plus prześwit nad nim (odstęp), żeby wyspa nie chowała się pod dokiem.
const DOCK_TOOL := 46.0
const DOCK_GAP := 24.0
```

i w `_layout()`:

```gdscript
	var bottom := vis.y - SafeArea.bottom_inset(get_viewport()) - MedievalTheme.px(DOCK_TOOL) - MedievalTheme.gap(DOCK_GAP)
	...
	hint_panel.offset_left = MedievalTheme.gap(HINT_MARGIN)
```

`scenes/views/WorldMap.gd`, w `_style_ui()` i `_layout_ui()`:

```gdscript
	zoom_controls.add_theme_constant_override("separation", MedievalTheme.gap(8))
	...
	var m := MedievalTheme.gap(UI_MARGIN)
```

Istniejący `test_map_ui_follows_hud_bar_after_rotation` w `test/scenes/world_map_test.gd` liczy oczekiwany margines tą samą funkcją co kod, więc zmień w nim jedną linię:

```gdscript
	var m := MedievalTheme.gap(WORLD_MAP_SCRIPT.UI_MARGIN)
```

- [ ] **Step 4: Uruchom testy i smoke**

```bash
./run_tests.sh test/scenes
./run_smoke.sh
```

Oczekiwane: zielono. Smoke dotyka przycisków doku i plakietki powrotu przez ich środek, więc przesunięcia nie powinny mu przeszkadzać.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/SheetStyle.gd scenes/ui/BuildingSheet.gd scenes/ui/FleetsSheet.gd scenes/ui/Dock.gd scenes/views/IslandDetail.gd scenes/views/WorldMap.gd test/scenes/sheets_test.gd test/scenes/dock_test.gd test/scenes/world_map_test.gd
git commit -m "Route sheet, dock, settlement-view and map spacing through gap()"
```

---

### Task 3: Pasek w dwóch wierszach, populacja w widoku osady

**Files:**
- Modify: `scenes/ui/HUD.tscn` (całość), `scenes/ui/HUD.gd` (całość), `scenes/views/IslandDetail.tscn` (warstwa `UI`), `scenes/views/IslandDetail.gd`, `tools/smoke_probe.gd` (dwa sprawdzenia populacji), `tools/capture_probe.gd` (wycinki)
- Test: `test/scenes/hud_test.gd`, `test/scenes/island_detail_test.gd`, `test/scenes/world_map_test.gd` (jedna linia)

**Interfaces:**
- Consumes: `MedievalTheme.gap()`/`px()` z Task 1, stałe `IslandDetail.DOCK_TOOL`/`DOCK_GAP` z Task 2.
- Produces: `HUD.identity_row: HBoxContainer`, pola `settlement_name`, `biome_badge`, `subtitle`, `resource_grid`, `cards`, metody `icon_of`, `amount_of`, `rate_of`, `bar_height()`, sygnał `bar_height_changed` — bez zmian nazw. Znikają `HUD.avatar`, `gold_icon`, `gold_label`, `pop_icon`, `pop_bar`, `pop_label`, `profile_row`, `AVATAR`, `SMALL_ICON`, `POP_WARN`. Pojawiają się `IslandDetail.status_row`, `pop_panel`, `pop_icon`, `pop_bar`, `pop_label`, `POP_WARN`. `HUD.DIMMED` zostaje do Task 5.

- [ ] **Step 1: Testy paska**

W `test/scenes/hud_test.gd` dodaj `MedievalTheme.install()` jako pierwszą linię `before_test()`:

```gdscript
func before_test() -> void:
	# Geometria paska zależy od fontów i rozmiarów z motywu; bez tego test mierzyłby domyślny
	# motyw silnika, a nie to, co widzi gracz.
	MedievalTheme.install()
	GameState.reset()
	...
```

Usuń z `test_profile_row_shows_active_settlement` linię z `gold_label`. Usuń cały `test_population_bar_and_warning` (populacja przenosi się do widoku osady i ma własne testy w Step 2). Dopisz:

```gdscript
## Wybrany wariant: dwa wiersze, cel około 14 %, próg 16 %. Mierzone przy oknie w proporcjach
## telefonu i z wgranym motywem, czyli w konfiguracji, którą widzi gracz.
func test_bar_stays_within_the_height_budget() -> void:
	var original := get_tree().root.size
	get_tree().root.size = Vector2i(1080, 1920)
	var hud := _hud()
	await await_idle_frame()
	await await_idle_frame()
	await await_idle_frame()
	var ratio := hud.bar_height() / hud.get_viewport().get_visible_rect().size.y
	get_tree().root.size = original
	assert_float(ratio).is_greater(0.0)
	assert_float(ratio).is_less_equal(0.16)


func test_bar_has_only_identity_and_resource_rows() -> void:
	var hud := _hud()
	assert_int(hud.bar_rows.get_child_count()).is_equal(2)
	assert_object(hud.settlement_name.get_parent()).is_same(hud.identity_row)
	assert_object(hud.biome_badge.get_parent()).is_same(hud.identity_row)
	assert_object(hud.subtitle.get_parent()).is_same(hud.identity_row)
	for gone in ["avatar", "gold_label", "pop_label", "pop_bar"]:
		assert_bool(gone in hud).override_failure_message("pasek wciąż ma %s" % gone).is_false()
```

W `test/scenes/world_map_test.gd`, w `test_map_ui_follows_hud_bar_after_rotation`, w orientacji poziomej karty trafiają teraz do wiersza tożsamości:

```gdscript
	assert_object(hud.resource_grid.get_parent()).is_same(hud.identity_row)
```

- [ ] **Step 2: Testy populacji w widoku osady**

Dopisz do `test/scenes/island_detail_test.gd`:

```gdscript
## Pełne ustawienie od zera, żeby osada aktywna na pewno miała podaną populację.
func _apply_home(population: int, population_max: int) -> void:
	GameState.reset()
	GameState.apply_world(FixtureCells.world_json())
	GameState.apply_settlements([{
		"x": HOME.x, "y": HOME.y, "ownerId": 7, "name": "Koralowa",
		"resources": {}, "buildings": {},
		"population": population, "populationMax": population_max,
	}])
	GameState.set_active_settlement(HOME)


func test_population_is_shown_in_the_settlement_view() -> void:
	_apply_home(42, 120)
	var det := _detail()
	assert_bool(det.pop_panel.visible).is_true()
	assert_str(det.pop_label.text).is_equal("42 / 120")
	assert_float(det.pop_bar.max_value).is_equal(120.0)
	assert_float(det.pop_bar.value).is_equal(42.0)
	assert_that(det.pop_label.get_theme_color("font_color")).is_equal(MedievalTheme.INK)


func test_population_near_the_limit_warns_in_blood() -> void:
	_apply_home(118, 120)
	var det := _detail()
	assert_that(det.pop_label.get_theme_color("font_color")).is_equal(MedievalTheme.BLOOD)


## Osada bez limitu (0 / 0) nie jest „zapełniona” - wcześniejsza wersja w pasku ostrzegała
## wtedy na czerwono, bo 0 >= 0 × 0,95.
func test_zero_population_limit_does_not_warn() -> void:
	_apply_home(0, 0)
	var det := _detail()
	assert_that(det.pop_label.get_theme_color("font_color")).is_equal(MedievalTheme.INK)


func test_population_hidden_without_active_settlement() -> void:
	GameState.reset()
	var det := _detail()
	assert_bool(det.pop_panel.visible).is_false()
```

- [ ] **Step 3: Uruchom, oczekuj porażek**

```bash
./run_tests.sh test/scenes/hud_test.gd
./run_tests.sh test/scenes/island_detail_test.gd
```

Oczekiwane: `test_bar_stays_within_the_height_budget` pada na proporcji około 0,24; `test_bar_has_only_identity_and_resource_rows` pada, bo `identity_row` nie istnieje; testy populacji padają, bo `pop_panel` nie istnieje. Zbierz RED po jednym teście.

- [ ] **Step 4: Przepisz `scenes/ui/HUD.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/HUD.gd" id="1"]

[node name="HUD" type="CanvasLayer" groups=["hud"]]
layer = 10
script = ExtResource("1")

[node name="TopBar" type="PanelContainer" parent="."]
anchors_preset = 10
anchor_right = 1.0
grow_horizontal = 2
mouse_filter = 2
theme_type_variation = &"BarPanel"

[node name="Pad" type="MarginContainer" parent="TopBar"]
layout_mode = 2
mouse_filter = 2

[node name="BarRows" type="VBoxContainer" parent="TopBar/Pad"]
layout_mode = 2
mouse_filter = 2

[node name="IdentityRow" type="HBoxContainer" parent="TopBar/Pad/BarRows"]
layout_mode = 2
mouse_filter = 2

[node name="SettlementName" type="Label" parent="TopBar/Pad/BarRows/IdentityRow"]
layout_mode = 2
size_flags_horizontal = 3
text = "-"
clip_text = true
theme_type_variation = &"Title"

[node name="BiomeBadge" type="Label" parent="TopBar/Pad/BarRows/IdentityRow"]
layout_mode = 2
size_flags_vertical = 4
theme_type_variation = &"Badge"

[node name="Subtitle" type="Label" parent="TopBar/Pad/BarRows/IdentityRow"]
layout_mode = 2
size_flags_vertical = 4
theme_type_variation = &"Caption"

[node name="ResourceGrid" type="HBoxContainer" parent="TopBar/Pad/BarRows"]
layout_mode = 2
mouse_filter = 2
```

Każdy węzeł dekoracyjny ma `mouse_filter = 2`, jak dotąd: przeciąganie mapy od paska jest wymaganiem pilnowanym przez smoke test.

- [ ] **Step 5: Przepisz `scenes/ui/HUD.gd`**

```gdscript
extends CanvasLayer

## Górny pasek osady aktywnej: wiersz tożsamości i pięć kart zasobów. Nie liczy nic sam:
## woła Settlement.current_resources(TimeUtil.now()). Pokazuje wyłącznie osadę aktywną;
## oglądana wyspa to zadanie InspectSheet, a populacja mieszka w widoku osady.

## Emitowany, gdy wysokość paska naprawdę się zmieniła - po ustaleniu layoutu, nie w trakcie.
## Widoki podpięte do samego size_changed czytają bar_height() jeszcze sprzed przepięcia
## ResourceGrid (przesortowanie kontenera jest odroczone), więc potrzebują tego sygnału.
signal bar_height_changed

## Przyciemnienie karty zasobu, którego osada nie produkuje (45% krycia).
const DIMMED := 0.45
const PAD := 12.0
const ICON := 24.0

@onready var top_bar: PanelContainer = $TopBar
@onready var pad: MarginContainer = $TopBar/Pad
@onready var bar_rows: VBoxContainer = $TopBar/Pad/BarRows
@onready var identity_row: HBoxContainer = $TopBar/Pad/BarRows/IdentityRow
@onready var settlement_name: Label = $TopBar/Pad/BarRows/IdentityRow/SettlementName
@onready var biome_badge: Label = $TopBar/Pad/BarRows/IdentityRow/BiomeBadge
@onready var subtitle: Label = $TopBar/Pad/BarRows/IdentityRow/Subtitle
@onready var resource_grid: HBoxContainer = $TopBar/Pad/BarRows/ResourceGrid

var _settlement: Settlement = null
## zasób -> PanelContainer (cała karta)
var cards: Dictionary = {}
var _icons: Dictionary = {}
var _amounts: Dictionary = {}
var _rates: Dictionary = {}
var _last_bar_height := -1.0


func _ready() -> void:
	_style_static_nodes()
	_build_cards()
	GameState.active_settlement_changed.connect(_on_active_changed)
	GameState.settlement_updated.connect(_on_settlement_updated)
	get_viewport().size_changed.connect(_on_size_changed)
	top_bar.resized.connect(_notify_bar_height)
	_on_size_changed()
	_on_active_changed()


func _style_static_nodes() -> void:
	var p := MedievalTheme.gap(PAD)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, p)
	bar_rows.add_theme_constant_override("separation", MedievalTheme.gap(9))
	identity_row.add_theme_constant_override("separation", MedievalTheme.gap(10))
	resource_grid.add_theme_constant_override("separation", MedievalTheme.gap(6))


func _build_cards() -> void:
	for r in ResourceTypes.ALL:
		var card := PanelContainer.new()
		card.name = r.capitalize() + "Card"
		card.theme_type_variation = &"ResCard"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", MedievalTheme.gap(2))
		var top := HBoxContainer.new()
		top.name = "TopRow"
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Icon.new()
		icon.name = "Icon"
		icon.kind = ResourceTypes.ICONS[r]
		icon.color = ResourceTypes.COLORS[r]
		icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
		var amount := Label.new()
		amount.name = "Amount"
		amount.theme_type_variation = &"Amount"
		amount.text = "0"
		var rate := Label.new()
		rate.name = "Rate"
		rate.theme_type_variation = &"Rate"
		top.add_child(icon)
		top.add_child(amount)
		box.add_child(top)
		box.add_child(rate)
		card.add_child(box)
		resource_grid.add_child(card)
		cards[r] = card
		_icons[r] = icon
		_amounts[r] = amount
		_rates[r] = rate


func icon_of(resource: String) -> Icon:
	return _icons[resource]


func amount_of(resource: String) -> Label:
	return _amounts[resource]


func rate_of(resource: String) -> Label:
	return _rates[resource]


## Dolna krawędź paska w pikselach canvasu; widoki układają pod nią swoje UI.
func bar_height() -> float:
	return top_bar.offset_top + top_bar.size.y


## Sygnał leci tylko przy realnej zmianie, więc wolno wołać to i z resized, i z size_changed:
## ta pierwsza wartość bywa jeszcze sprzed przesortowania, druga zawsze ją domyka.
func _notify_bar_height() -> void:
	var h := bar_height()
	if is_equal_approx(h, _last_bar_height):
		return
	_last_bar_height = h
	bar_height_changed.emit()


func _on_active_changed() -> void:
	_settlement = GameState.active_settlement
	if _settlement == null:
		settlement_name.text = "-"
		biome_badge.text = ""
		subtitle.text = ""
		for r in ResourceTypes.ALL:
			_amounts[r].text = "0"
			_rates[r].text = ""
			cards[r].modulate.a = 1.0
		return
	settlement_name.text = _settlement.name
	biome_badge.text = Biome.key(_settlement.biome)
	var world_id := GameState.world.id if GameState.world != null else "?"
	subtitle.text = "Świat %s · (%d, %d)" % [world_id, _settlement.coord.x, _settlement.coord.y]
	for r in ResourceTypes.ALL:
		var produces := _settlement.produces(r)
		_rates[r].text = "+%d/h" % int(_settlement.production_per_hour[r]) if produces else ""
		cards[r].modulate.a = 1.0 if produces else DIMMED


func _on_settlement_updated(coord: Vector2i) -> void:
	if _settlement != null and coord == _settlement.coord:
		_on_active_changed()


func _process(_delta: float) -> void:
	if _settlement == null:
		return
	var current := _settlement.current_resources(TimeUtil.now())
	for r in ResourceTypes.ALL:
		_amounts[r].text = TimeUtil.format_thousands(current[r])


func _on_size_changed() -> void:
	top_bar.offset_top = SafeArea.top_inset(get_viewport())
	_apply_orientation()
	_notify_bar_height()


## Portret: karty zasobów pod wierszem tożsamości. Landscape: karty w tym samym wierszu po prawej,
## żeby obszar gry zachował wysokość.
func _apply_orientation() -> void:
	var vis := get_viewport().get_visible_rect().size
	var landscape := vis.x > vis.y
	var parent := resource_grid.get_parent()
	if landscape and parent != identity_row:
		parent.remove_child(resource_grid)
		identity_row.add_child(resource_grid)
		resource_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif not landscape and parent != bar_rows:
		parent.remove_child(resource_grid)
		bar_rows.add_child(resource_grid)
		bar_rows.move_child(resource_grid, 1)
		resource_grid.size_flags_horizontal = Control.SIZE_FILL
```

- [ ] **Step 6: Warstwa `UI` w `scenes/views/IslandDetail.tscn`**

Zastąp węzły `HintPanel` i `Hint` poniższym blokiem, dodaj zasób skryptu ikony i podnieś `load_steps` do 4:

```
[ext_resource type="Script" path="res://scenes/ui/Icon.gd" id="3"]
...
[node name="UI" type="CanvasLayer" parent="."]
layer = 1

[node name="StatusRow" type="HBoxContainer" parent="UI"]
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
grow_vertical = 0
mouse_filter = 2

[node name="PopPanel" type="PanelContainer" parent="UI/StatusRow"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"Plaque"

[node name="HBox" type="HBoxContainer" parent="UI/StatusRow/PopPanel"]
layout_mode = 2
mouse_filter = 2

[node name="PopIcon" type="Control" parent="UI/StatusRow/PopPanel/HBox"]
layout_mode = 2
size_flags_vertical = 4
script = ExtResource("3")
kind = &"people"

[node name="PopBar" type="ProgressBar" parent="UI/StatusRow/PopPanel/HBox"]
layout_mode = 2
size_flags_vertical = 4
mouse_filter = 2
max_value = 1.0
show_percentage = false

[node name="PopLabel" type="Label" parent="UI/StatusRow/PopPanel/HBox"]
layout_mode = 2
text = "0 / 0"
theme_type_variation = &"Amount"

[node name="HintPanel" type="PanelContainer" parent="UI/StatusRow"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"Plaque"

[node name="Hint" type="Label" parent="UI/StatusRow/HintPanel"]
layout_mode = 2
text = "Dotknij slotu, żeby otworzyć budynek"
```

Plakietka populacji stoi pierwsza, bo jest stała; podpowiedź, która znika po pierwszym otwarciu budynku, stoi za nią, więc jej zniknięcie nie przesuwa populacji.

- [ ] **Step 7: `scenes/views/IslandDetail.gd`**

Zmień komentarz nagłówkowy, stałe i ścieżki węzłów:

```gdscript
extends Node2D

## Dom gracza: osada aktywna z plakietkami slotów. Cudze i niczyje wyspy obsługuje InspectSheet
## nad mapą, nie ten widok. Tap w slot otwiera BuildingSheet przez grupę "sheets".
## Populacja mieszka tutaj, nie w pasku: zmienia ją tylko rekrutacja, a ta dzieje się w osadzie.

const DETAIL_RADIUS := 400.0
## Przycisk docku (rozmiar) plus prześwit nad nim (odstęp), żeby wyspa nie chowała się pod dokiem.
const DOCK_TOOL := 46.0
const DOCK_GAP := 24.0
const HINT_MARGIN := 10.0
const HINT_TEXT := "Dotknij slotu, żeby otworzyć budynek"
const NO_SETTLEMENT_TEXT := "Brak osady"
const POP_ICON := 16.0
const POP_BAR := Vector2(90.0, 8.0)
## Od tego zapełnienia limitu populacja ostrzega kolorem BLOOD.
const POP_WARN := 0.95

@onready var generator: IslandGenerator = $Generator
@onready var camera: Camera2D = $Camera
@onready var status_row: HBoxContainer = $UI/StatusRow
@onready var pop_panel: PanelContainer = $UI/StatusRow/PopPanel
@onready var pop_icon: Icon = $UI/StatusRow/PopPanel/HBox/PopIcon
@onready var pop_bar: ProgressBar = $UI/StatusRow/PopPanel/HBox/PopBar
@onready var pop_label: Label = $UI/StatusRow/PopPanel/HBox/PopLabel
@onready var hint_panel: PanelContainer = $UI/StatusRow/HintPanel
@onready var hint_label: Label = $UI/StatusRow/HintPanel/Hint
```

Pola `_settlement`, `_pressed_slot`, `_pressed_index`, `_hint_dismissed` bez zmian. W `_ready()` jako pierwszą linię wołaj `_style_status()` i dodaj tę funkcję:

```gdscript
func _style_status() -> void:
	status_row.add_theme_constant_override("separation", MedievalTheme.gap(8))
	(pop_panel.get_node("HBox") as HBoxContainer).add_theme_constant_override("separation", MedievalTheme.gap(6))
	pop_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(POP_ICON)
	pop_icon.color = MedievalTheme.INK_SOFT
	pop_bar.custom_minimum_size = Vector2(MedievalTheme.px(POP_BAR.x), MedievalTheme.px(POP_BAR.y))
```

Przepisz `_refresh()` i dodaj `_show_population()`:

```gdscript
func _refresh() -> void:
	_settlement = GameState.active_settlement
	_pressed_slot = -1
	_pressed_index = -1
	if _settlement == null:
		generator.clear()
		pop_panel.hide()
		hint_label.text = NO_SETTLEMENT_TEXT
		hint_panel.show()
		return
	var island := GameState.island_at(_settlement.coord)
	generator.seed_val = island.seed_val if island != null else hash(_settlement.coord)
	generator.biome = _settlement.biome
	generator.radius = DETAIL_RADIUS
	generator.show_deposit = false
	generator.show_slots = true
	generator.settlement = _settlement
	generator.build()
	_show_population()
	hint_label.text = HINT_TEXT
	hint_panel.visible = not _hint_dismissed


func _show_population() -> void:
	pop_panel.show()
	pop_bar.max_value = maxi(_settlement.population_max, 1)
	pop_bar.value = _settlement.population
	pop_label.text = "%d / %d" % [_settlement.population, _settlement.population_max]
	var warn := (
		_settlement.population_max > 0
		and _settlement.population >= float(_settlement.population_max) * POP_WARN
	)
	pop_label.add_theme_color_override("font_color", MedievalTheme.BLOOD if warn else MedievalTheme.INK)
```

W `_layout()` zamień dwie ostatnie linie ustawiające `hint_panel` na `status_row`:

```gdscript
	status_row.offset_left = MedievalTheme.gap(HINT_MARGIN)
	status_row.offset_bottom = -(vis.y - bottom)
```

- [ ] **Step 8: Smoke probe i sonda zrzutów**

W `tools/smoke_probe.gd`, w klatce `20`, zastąp sprawdzenie populacji w pasku sprawdzeniem w widoku osady, po linii definiującej `det`:

```gdscript
			_check(det != null and det.pop_label.text == "42 / 120", "widok osady pokazuje populację")
```

i usuń linię `_check(hud.pop_label.text == "42 / 120", "HUD pokazuje populację")`. W kroku po `ApiClient.resync()` (sprawdzenie „HUD po resyncu”) zamień warunek na nazwę osady, bo na mapie populacji nie ma:

```gdscript
			_check(get_node("Main/HUD").settlement_name.text == "Koralowa", "HUD po resyncu")
```

W `tools/capture_probe.gd` zastąp `CROPS` wycinkami nowego układu:

```gdscript
## Wycinki zapisywane dodatkowo w skali 1:1, żeby dało się ocenić szczegół bez skalowania.
## Klucz to nazwa pliku, wartość to prostokąt w pikselach canvasu.
const CROPS := {
	"pasek": Rect2i(0, 0, 1080, 320),
	"status-osady": Rect2i(0, 1600, 1080, 320),
}
```

- [ ] **Step 9: Testy, smoke i pomiar**

```bash
./run_tests.sh test/scenes/hud_test.gd
./run_tests.sh test/scenes/island_detail_test.gd
./run_tests.sh
./run_smoke.sh
mkdir -p /tmp/ui-polish-task3
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 1080x1920 res://tools/Capture.tscn -- /tmp/ui-polish-task3 2>&1 | grep -E 'MEASURE|LABEL|ZA WĄSKA|SCRIPT ERROR'
```

Oczekiwane: testy i smoke zielone; sonda raportuje `bar_height` około 267 px, czyli około 13,9 %, i żadna etykieta nie jest `ZA WĄSKA`. Wklej ten wynik do raportu.

- [ ] **Step 10: Commit**

```bash
git add scenes/ui/HUD.tscn scenes/ui/HUD.gd scenes/views/IslandDetail.tscn scenes/views/IslandDetail.gd tools/smoke_probe.gd tools/capture_probe.gd test/scenes/hud_test.gd test/scenes/island_detail_test.gd test/scenes/world_map_test.gd
git commit -m "Shrink the top bar to two rows and move population to the settlement view"
```

---

### Task 4: Kolor wycięcia w `Icon` i nowa ikona kamienia

**Files:**
- Modify: `scenes/ui/Icon.gd`, `scenes/ui/SheetStyle.gd`, `scenes/ui/BuildingSheet.gd` (`refresh_costs`)
- Test: `test/scenes/icon_test.gd`, `test/scenes/inspect_sheet_test.gd`, `test/scenes/building_sheet_test.gd`

**Interfaces:**
- Produces: `Icon.knockout: Color` (eksport, domyślnie `MedievalTheme.PARCHMENT`, setter woła `queue_redraw()`); `static func into_button(button: Button, k: StringName, c: Color, inset: float, knockout_color: Color = MedievalTheme.OAK) -> Icon`; `static func SheetStyle.chip_icon(chip: PanelContainer) -> Icon`. Ikona w chipie ma nazwę węzła `Icon`.
- Task 5 ustawia `knockout` ikon kart zasobów na kolor twarzy karty.

Wycięcie to kolor tła, na którym ikona leży; wtedy okno ratusza, fałdy mapy czy żyłka kamienia czytają się jak dziura, a nie jak jasna plama. Dziś siedem miejsc wpisuje na sztywno `PARCHMENT`, co jest błędem wszędzie tam, gdzie tło jest dębowe: nagłówki arkuszy (`ModalHeader`, `OAK`), przyciski doku i mapy (`ToolButton`, `OAK`), chipy zasobów (`Chip`, `OAK_DEEP`).

- [ ] **Step 1: Testy**

Dopisz do `test/scenes/icon_test.gd`:

```gdscript
func test_knockout_defaults_to_parchment_and_stores_a_set_value() -> void:
	var icon: Icon = auto_free(Icon.new())
	assert_that(icon.knockout).is_equal(MedievalTheme.PARCHMENT)
	icon.knockout = MedievalTheme.OAK
	assert_that(icon.knockout).is_equal(MedievalTheme.OAK)


## Strażnik tekstowy: jedynym miejscem, gdzie Icon.gd zna PARCHMENT, ma być wartość domyślna
## eksportu. Każde inne wystąpienie to glif, który zignoruje ustawiony knockout i narysuje
## pergaminową dziurę na dębowym tle.
func test_glyphs_draw_cutouts_only_through_knockout() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/ui/Icon.gd")
	assert_int(source.count("MedievalTheme.PARCHMENT")).is_equal(1)


## Każdy przycisk z ikoną w tym projekcie ma dębowe tło (ToolButton), więc to jest wartość domyślna.
func test_into_button_cuts_out_in_oak_by_default() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	assert_that(Icon.into_button(button, &"map", Color.WHITE, 6.0).knockout).is_equal(MedievalTheme.OAK)
	var other: Button = auto_free(Button.new())
	add_child(other)
	assert_that(Icon.into_button(other, &"map", Color.WHITE, 6.0, MedievalTheme.INK).knockout).is_equal(MedievalTheme.INK)
```

Dopisz do `test/scenes/inspect_sheet_test.gd`:

```gdscript
## Nagłówek arkusza leży na dębie (ModalHeader), chip zasobu na ciemnym dębie (Chip).
func test_header_and_chip_icons_cut_out_in_their_own_background() -> void:
	var s := _sheet()
	assert_that(s.biome_icon.knockout).is_equal(MedievalTheme.OAK)
	var chip: PanelContainer = auto_free(SheetStyle.resource_chip("sulfur"))
	assert_that(SheetStyle.chip_icon(chip).knockout).is_equal(MedievalTheme.OAK_DEEP)
```

Dopisz do `test/scenes/building_sheet_test.gd` (pomocniki `_sheet()` i `_settlement()` już są w pliku):

```gdscript
## refresh_costs przemalowuje tło chipa (VELLUM albo SHORT_BG), więc wycięcie ikony musi pójść za nim.
func test_cost_chip_icon_cuts_out_in_the_chip_background() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.TOWN_HALL)
	s.refresh_costs({"sulfur": 100.0, "wood": 10.0}, {"wood": 50.0})
	assert_that(SheetStyle.chip_icon(s.cost_chips["sulfur"]).knockout).is_equal(MedievalTheme.SHORT_BG)
	assert_that(SheetStyle.chip_icon(s.cost_chips["wood"]).knockout).is_equal(MedievalTheme.VELLUM)
```

- [ ] **Step 2: Uruchom po jednym, oczekuj porażek**

```bash
./run_tests.sh test/scenes/icon_test.gd
./run_tests.sh test/scenes/inspect_sheet_test.gd
./run_tests.sh test/scenes/building_sheet_test.gd
```

Oczekiwane: błąd parsowania albo porażki, bo `knockout` i `SheetStyle.chip_icon` nie istnieją, a źródło `Icon.gd` zawiera `MedievalTheme.PARCHMENT` osiem razy.

- [ ] **Step 3: `scenes/ui/Icon.gd`**

Pod eksportem `color` dodaj:

```gdscript
## Kolor wycięć w glifie (okno ratusza, fałdy mapy, żyłka kamienia). Ma być kolorem tła,
## na którym ikona leży - wtedy wycięcie czyta się jak dziura, a nie jak jasna plama.
@export var knockout: Color = MedievalTheme.PARCHMENT:
	set(v):
		knockout = v
		queue_redraw()
```

Zastąp `into_button`:

```gdscript
## Dodaje ikonę jako dziecko przycisku, rozciągniętą na cały przycisk z marginesem inset (px).
## Wycięcie domyślnie dębowe, bo każdy przycisk z ikoną w tym projekcie to ToolButton na OAK.
static func into_button(button: Button, k: StringName, c: Color, inset: float,
		knockout_color: Color = MedievalTheme.OAK) -> Icon:
	var icon := Icon.new()
	icon.name = "Icon"
	icon.kind = k
	icon.color = c
	icon.knockout = knockout_color
	button.add_child(icon)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	return icon
```

W siedmiu glifach zamień `MedievalTheme.PARCHMENT` na `knockout`: `_draw_sulfur` (kropka), `_draw_town_hall` (drzwi), `_draw_warehouse` (drzwi), `_draw_map` (dwie fałdy), `_draw_gold` (wewnętrzny okrąg), `_draw_trade` (pas). Po zmianie `grep -c "MedievalTheme.PARCHMENT" scenes/ui/Icon.gd` ma dać `1`.

Zastąp `_draw_stone`:

```gdscript
## Bryła z jedną wewnętrzną krawędzią, która dzieli ją na dwie płaszczyzny. Płaski sześciokąt
## czytał się w tej skali jak plama.
func _draw_stone() -> void:
	_poly([Vector2(5, 15), Vector2(8, 7), Vector2(14, 4), Vector2(20, 8), Vector2(21, 16), Vector2(15, 20), Vector2(8, 20)])
	draw_polyline(PackedVector2Array([Vector2(14, 4), Vector2(12, 12), Vector2(15, 20)]), knockout, 1.6, true)
```

Krawędź biegnie od górnego do dolnego wierzchołka bryły, więc naprawdę dzieli ją na dwie części.

- [ ] **Step 4: `scenes/ui/SheetStyle.gd`**

W `apply_common`, po `header_icon.color = MedievalTheme.CREAM`:

```gdscript
	header_icon.knockout = MedievalTheme.OAK   # nagłówek ModalHeader ma tło OAK
```

W `resource_chip` nazwij ikonę i ustaw wycięcie:

```gdscript
	var icon := Icon.new()
	icon.name = "Icon"
	icon.kind = ResourceTypes.ICONS[resource]
	icon.color = ResourceTypes.COLORS[resource]
	icon.knockout = MedievalTheme.OAK_DEEP   # tło wariacji Chip
	icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(icon_size)
```

Pod `chip_amount` dodaj:

```gdscript
## Ikona zasobu w chipie zbudowanym przez resource_chip(); wołający, który przemalowuje tło
## chipa, musi przestawić też jej wycięcie.
static func chip_icon(chip: PanelContainer) -> Icon:
	return chip.get_node("Box/Icon") as Icon
```

- [ ] **Step 5: `scenes/ui/BuildingSheet.gd`, `refresh_costs`**

Wyciągnij kolor tła do zmiennej i przekaż go ikonie:

```gdscript
		var short := held < required
		var bg := MedievalTheme.SHORT_BG if short else MedievalTheme.VELLUM
		var sb := MedievalTheme.flat(bg, MedievalTheme.BLOOD if short else MedievalTheme.OAK_EDGE, 3, 1, 8, 8)
		chip.add_theme_stylebox_override("panel", sb)
		SheetStyle.chip_icon(chip).knockout = bg
```

- [ ] **Step 6: Testy i smoke**

```bash
./run_tests.sh test/scenes
./run_smoke.sh
```

Oczekiwane: zielono, w tym `test_every_kind_draws_one_frame` z nowym glifem kamienia.

- [ ] **Step 7: Commit**

```bash
git add scenes/ui/Icon.gd scenes/ui/SheetStyle.gd scenes/ui/BuildingSheet.gd test/scenes/icon_test.gd test/scenes/inspect_sheet_test.gd test/scenes/building_sheet_test.gd
git commit -m "Cut icon glyphs out in their background colour and redraw the stone icon"
```

---

### Task 5: Karta zasobu nieprodukowanego czytelna przez paletę

**Files:**
- Modify: `scenes/ui/HUD.gd`
- Test: `test/scenes/hud_test.gd`

**Interfaces:**
- Consumes: `Icon.knockout` z Task 4; `HUD` z Task 3.
- Produces: `HUD._apply_card_state(r: String, produces: bool)`. Znika `HUD.DIMMED`.

Dziś karta nieprodukowanego zasobu dostaje `modulate.a = 0.45`. `modulate` mnoży alfę karty razem z dziećmi, więc pergamin robi się półprzezroczysty na dębie, a liczba blaknie razem z nim. Zamiast tego stan niosą kolory i treść, przy pełnej nieprzezroczystości:

| Element | Produkowany | Nieprodukowany |
|---|---|---|
| Tło karty | `PARCHMENT` | `VELLUM` |
| Liczba | `INK` | `INK_SOFT` |
| Ikona | `ResourceTypes.COLORS[r]` | `INK_SOFT` |
| Wycięcie ikony | `PARCHMENT` | `VELLUM` |
| Tempo | `+120/h` | puste |

- [ ] **Step 1: Testy**

W `test/scenes/hud_test.gd`, w `test_cards_show_amounts_and_rates`, usuń dwie ostatnie linie (komentarz o float32 i asercje `modulate.a`). Dopisz:

```gdscript
func _face(hud: CanvasLayer, r: String) -> Color:
	return (hud.cards[r].get_theme_stylebox("panel") as StyleBoxFlat).bg_color


func test_idle_resource_differs_by_palette_not_by_alpha() -> void:
	var hud := _hud()
	assert_that(_face(hud, "wood")).is_equal(MedievalTheme.PARCHMENT)
	assert_that(_face(hud, "stone")).is_equal(MedievalTheme.VELLUM)
	assert_that(hud.icon_of("wood").color).is_equal(ResourceTypes.COLORS["wood"])
	assert_that(hud.icon_of("stone").color).is_equal(MedievalTheme.INK_SOFT)
	assert_that(hud.icon_of("stone").knockout).is_equal(MedievalTheme.VELLUM)
	assert_that(hud.amount_of("wood").get_theme_color("font_color")).is_equal(MedievalTheme.INK)
	assert_that(hud.amount_of("stone").get_theme_color("font_color")).is_equal(MedievalTheme.INK_SOFT)
	for r in ResourceTypes.ALL:
		assert_float(hud.cards[r].modulate.a).override_failure_message("karta %s przyciemniona" % r).is_equal(1.0)


## Stan karty nie może się „przykleić”: przełączenie na osadę z innym biomem odwraca go w obie strony.
func test_card_state_follows_the_active_settlement() -> void:
	GameState.apply_settlements([{
		"x": FixtureCells.OWN_SECOND.x, "y": FixtureCells.OWN_SECOND.y, "ownerId": 7, "name": "Popielna",
		"resources": {"iron": 900}, "productionPerHour": {"iron": 60, "sulfur": 40},
	}])
	var hud := _hud()
	assert_that(_face(hud, "iron")).is_equal(MedievalTheme.VELLUM)
	GameState.set_active_settlement(FixtureCells.OWN_SECOND)
	assert_that(_face(hud, "iron")).is_equal(MedievalTheme.PARCHMENT)
	assert_that(_face(hud, "wood")).is_equal(MedievalTheme.VELLUM)
	assert_that(hud.icon_of("wood").color).is_equal(MedievalTheme.INK_SOFT)
	assert_str(hud.rate_of("iron").text).is_equal("+60/h")
	assert_str(hud.rate_of("wood").text).is_equal("")
```

W `test_no_settlement_shows_dashes` dopisz na końcu:

```gdscript
	assert_that(_face(hud, "stone")).is_equal(MedievalTheme.PARCHMENT)
```

- [ ] **Step 2: Uruchom po jednym, oczekuj porażek**

```bash
./run_tests.sh test/scenes/hud_test.gd
```

Oczekiwane: `test_idle_resource_differs_by_palette_not_by_alpha` pada na tle `stone` (dziś `PARCHMENT` z motywu i `modulate.a` 0,45).

- [ ] **Step 3: Implementacja w `scenes/ui/HUD.gd`**

Usuń stałą `DIMMED` razem z jej komentarzem. W `_on_active_changed`, w gałęzi bez osady, zamień `cards[r].modulate.a = 1.0` na `_apply_card_state(r, true)`. W pętli dla osady:

```gdscript
	for r in ResourceTypes.ALL:
		var produces := _settlement.produces(r)
		_rates[r].text = "+%d/h" % int(_settlement.production_per_hour[r]) if produces else ""
		_apply_card_state(r, produces)
```

Dodaj pod `_on_active_changed`:

```gdscript
## Stan „nie produkuję” niosą paleta i treść, nie przezroczystość: modulate mnożyłby alfę także
## liczby i ikony, a półprzezroczysty pergamin na dębie wychodził błotem.
func _apply_card_state(r: String, produces: bool) -> void:
	var face := MedievalTheme.PARCHMENT if produces else MedievalTheme.VELLUM
	var card: PanelContainer = cards[r]
	# Najpierw zdejmujemy własne nadpisanie, żeby duplikować styl z motywu, a nie poprzedni stan.
	card.remove_theme_stylebox_override("panel")
	var base := card.get_theme_stylebox("panel")
	if base is StyleBoxFlat:
		var sb: StyleBoxFlat = base.duplicate()
		sb.bg_color = face
		card.add_theme_stylebox_override("panel", sb)
	var icon: Icon = _icons[r]
	icon.color = ResourceTypes.COLORS[r] if produces else MedievalTheme.INK_SOFT
	icon.knockout = face
	_amounts[r].add_theme_color_override("font_color", MedievalTheme.INK if produces else MedievalTheme.INK_SOFT)
```

- [ ] **Step 4: Testy, smoke i sonda**

```bash
./run_tests.sh test/scenes/hud_test.gd
./run_tests.sh
./run_smoke.sh
grep -rn "DIMMED" scenes test tools
```

Oczekiwane: zielono; `grep` nic nie znajduje.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/HUD.gd test/scenes/hud_test.gd
git commit -m "Show idle resources through palette instead of fading the whole card"
```

---

### Task 6: Położenie wyspy w kontrakcie; nawigacja na położeniach; artefakt parytetu

**Files:**
- Modify: `scripts/core/WorldGrid.gd`, `scripts/core/SeaNavigation.gd`, `scenes/autoload/GameState.gd`, `tools/world_parity_dump.gd`, `contract/world-parity.json` (regenerowany), `contract/README.md`
- Test: `test/core/world_grid_test.gd`, `test/core/sea_navigation_test.gd`, `test/state/game_state_test.gd`

**Interfaces:**
- Produces:
  - `WorldGrid.OFFSET_RANGE := 0.13`
  - `static func island_offset_xy(world_seed: int, cell: Vector2i) -> PackedFloat64Array` — `[offset_x, offset_y]` w ułamkach komórki, double, dokładnie wzór z ADR 0001, punkt 8.
  - `static func island_offset(world_seed: int, cell: Vector2i) -> Vector2` — to samo jako float32.
  - `static func island_position(world_seed: int, cell: Vector2i) -> Vector2` — `Vector2(cell) + island_offset`, jednostki komórek.
  - `static func island_center(world_seed: int, cell: Vector2i) -> Vector2` — `cell_to_world(cell) + island_offset * CELL_SIZE`, piksele.
  - `SeaNavigation.distance(a: Vector2, b: Vector2) -> float`, `SeaNavigation.travel_time(a: Vector2, b: Vector2, speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float`, `SeaNavigation.travel_time_between(world_seed: int, from_cell: Vector2i, to_cell: Vector2i, speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float`.
  - `GameState.world_seed() -> int` — `world.seed_val` albo 0 bez świata.
- Task 7 używa `island_center` i `world_seed()` do rysowania i trafiania.

Ten task nie zmienia niczego na ekranie. Wprowadza funkcje kontraktu i przepisuje nawigację; mapa zacznie z nich korzystać w Task 7.

- [ ] **Step 1: Testy `WorldGrid`**

Dopisz do `test/core/world_grid_test.gd`:

```gdscript
## Złote wartości policzone niezależnie w Pythonie ze wzoru w ADR 0001, Załącznik, punkt 8.
## Tolerancja 1e-15 zamiast równości: literał float w źródle GDScript przechodzi przez parser
## silnika, który dla części wartości myli się o 1 ULP (patrz tools/world_parity_dump.gd).
## Zgodność bit w bit sprawdza weryfikacja artefaktu kontraktu przy regeneracji (Task 6, Step 9).
## NIE aktualizować tych liczb bez świadomej decyzji o migracji świata - to jest kontrakt.
func test_golden_island_offsets_for_fixture_seed() -> void:
	var cases := {
		Vector2i(80, 73): [0.07367142999900071, -0.020720495653042865],
		Vector2i(81, 73): [0.1028230238832817, -0.04189567302887978],
		Vector2i(79, 73): [0.024799640251823716, -0.0904816628360148],
		Vector2i(87, 72): [0.07741281103227741, 0.04090836414509842],
	}
	for cell: Vector2i in cases:
		var got := WorldGrid.island_offset_xy(SEED, cell)
		var want: Array = cases[cell]
		assert_float(got[0]).override_failure_message("offset_x %s" % cell).is_equal_approx(want[0], 1e-15)
		assert_float(got[1]).override_failure_message("offset_y %s" % cell).is_equal_approx(want[1], 1e-15)


func test_island_offset_is_deterministic_and_within_range() -> void:
	for y in range(60, 90):
		for x in range(60, 90):
			var cell := Vector2i(x, y)
			var a := WorldGrid.island_offset_xy(SEED, cell)
			assert_that(WorldGrid.island_offset_xy(SEED, cell)).is_equal(a)
			for v in a:
				assert_float(v).is_greater_equal(-WorldGrid.OFFSET_RANGE)
				assert_float(v).is_less(WorldGrid.OFFSET_RANGE)


## Sole muszą różnić się od siebie: gdyby obie osie brały tę samą, wyspy przesuwałyby się
## wyłącznie po przekątnej.
func test_island_offset_axes_are_independent() -> void:
	var differ := 0
	for x in range(60, 90):
		var o := WorldGrid.island_offset_xy(SEED, Vector2i(x, 73))
		if not is_equal_approx(o[0], o[1]):
			differ += 1
	assert_int(differ).is_greater(25)


func test_island_position_and_center_follow_the_offset() -> void:
	var cell := Vector2i(80, 73)
	var off := WorldGrid.island_offset(SEED, cell)
	assert_that(WorldGrid.island_position(SEED, cell)).is_equal(Vector2(cell) + off)
	assert_that(WorldGrid.island_center(SEED, cell)).is_equal(WorldGrid.cell_to_world(cell) + off * WorldGrid.CELL_SIZE)
	# float32 widok nie odjeżdża od double o więcej niż precyzję float32
	var xy := WorldGrid.island_offset_xy(SEED, cell)
	assert_float(off.x).is_equal_approx(xy[0], 1e-6)
	assert_float(off.y).is_equal_approx(xy[1], 1e-6)
```

- [ ] **Step 2: Testy nawigacji**

Przepisz `test/core/sea_navigation_test.gd` od góry do `test_zero_speed_is_infinite` włącznie; `test_fleet_speed_is_slowest_ship` zostaje bez zmian:

```gdscript
extends GdUnitTestSuite

## Położenia w jednostkach komórek. Przy zerowym przesunięciu położenie wyspy to jej komórka,
## więc te liczby są dokładnie dawnymi odległościami między komórkami.
const A := Vector2(0, 0)
const B := Vector2(4, 0)
const HOME := FixtureCells.HOME
const FOREIGN := FixtureCells.FOREIGN
const SEED := FixtureCells.WORLD_SEED


func test_distance() -> void:
	assert_float(SeaNavigation.distance(A, B)).is_equal(4.0)
	assert_float(SeaNavigation.distance(Vector2(0, 0), Vector2(3, 4))).is_equal(5.0)


func test_distance_is_symmetric() -> void:
	var p := Vector2(80.07, 72.98)
	var q := Vector2(81.1, 72.96)
	assert_float(SeaNavigation.distance(p, q)).is_equal(SeaNavigation.distance(q, p))


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


## ADR 0003: czas podróży liczy się między położeniami wysp, nie między komórkami.
## Koralowa i Szara Skała są sąsiadami w poziomie; ich położenia są odsunięte o ~1,03 komórki.
func test_travel_time_between_measures_island_positions() -> void:
	var a := WorldGrid.island_position(SEED, HOME)
	var b := WorldGrid.island_position(SEED, FOREIGN)
	var got := SeaNavigation.travel_time_between(SEED, HOME, FOREIGN, 4.0)
	assert_float(got).is_equal(SeaNavigation.travel_time(a, b, 4.0))
	# Między komórkami wyszłoby równo 900 s; między położeniami ~926 s.
	assert_float(absf(got - SeaNavigation.travel_time(Vector2(HOME), Vector2(FOREIGN), 4.0))).is_greater(1.0)


## Kierunek wiatru liczy się po tym samym wektorze co odległość. Między komórkami ten wektor
## jest poziomy, więc wiatr z południa byłby neutralny; między położeniami ma składową pionową.
func test_wind_uses_the_vector_between_positions() -> void:
	var calm := SeaNavigation.travel_time_between(SEED, HOME, FOREIGN, 4.0)
	var windy := SeaNavigation.travel_time_between(SEED, HOME, FOREIGN, 4.0, Vector2(0, 1))
	assert_float(absf(windy - calm)).is_greater(0.5)
	var a := WorldGrid.island_position(SEED, HOME)
	var b := WorldGrid.island_position(SEED, FOREIGN)
	assert_float(windy).is_equal(SeaNavigation.travel_time(a, b, 4.0, Vector2(0, 1)))
```

- [ ] **Step 3: Test `GameState.world_seed()`**

Dopisz do `test/state/game_state_test.gd`:

```gdscript
func test_world_seed_falls_back_to_zero_without_a_world() -> void:
	var gs := _state()
	assert_int(gs.world_seed()).is_equal(1337)
	var empty: Node = auto_free(GameStateScript.new())
	assert_int(empty.world_seed()).is_equal(0)
```

- [ ] **Step 4: Uruchom, oczekuj porażek**

```bash
./run_tests.sh test/core/world_grid_test.gd
./run_tests.sh test/core/sea_navigation_test.gd
./run_tests.sh test/state/game_state_test.gd
```

Oczekiwane: błędy parsowania — `island_offset_xy`, `travel_time_between`, `world_seed` nie istnieją, a `SeaNavigation.distance` nie przyjmuje `Vector2`.

- [ ] **Step 5: `scripts/core/WorldGrid.gd`**

Pod `RADIUS_MAX` dodaj:

```gdscript
## Przesunięcie położenia wyspy w obrębie komórki, w ułamkach komórki, na każdej osi.
## Część kontraktu geografii (ADR 0001, Załącznik, punkt 8): wyznacza odległość podróży floty
## (ADR 0003). Zmiana po otwarciu świata zmienia czasy podróży, więc jest migracją świata.
const OFFSET_RANGE := 0.13
```

Pod `_deposit_for` dodaj:

```gdscript
## Przesunięcie położenia wyspy w obrębie komórki: [offset_x, offset_y] w ułamkach komórki,
## w pełnej precyzji double. Kontrakt geografii - ADR 0001, Załącznik, punkt 8; sole (13, 17)
## i (19, 23) oraz mapowanie * 2.0 - 1.0 przepisane dosłownie. Nie Vector2, bo Vector2 trzyma
## float32 i zgubiłby bity, które backend porównuje dokładnie (contract/world-parity.json).
## Kontrakt obejmuje komórki lądu; dla morza wynik jest liczony tak samo, ale nic go nie używa.
static func island_offset_xy(world_seed: int, cell: Vector2i) -> PackedFloat64Array:
	var h := hash_cell(world_seed, cell)
	var ox := (hash01(hash_cell(h, Vector2i(13, 17))) * 2.0 - 1.0) * OFFSET_RANGE
	var oy := (hash01(hash_cell(h, Vector2i(19, 23))) * 2.0 - 1.0) * OFFSET_RANGE
	return PackedFloat64Array([ox, oy])


## Widok float32 przesunięcia - do renderowania i nawigacji klienta.
static func island_offset(world_seed: int, cell: Vector2i) -> Vector2:
	var xy := island_offset_xy(world_seed, cell)
	return Vector2(xy[0], xy[1])


## Położenie wyspy w jednostkach komórek: między tymi punktami liczy się odległość podróży.
static func island_position(world_seed: int, cell: Vector2i) -> Vector2:
	return Vector2(cell) + island_offset(world_seed, cell)


## Środek wyspy w pikselach mapy. Rendering, nie kontrakt: CELL_SIZE zna tylko klient.
static func island_center(world_seed: int, cell: Vector2i) -> Vector2:
	return cell_to_world(cell) + island_offset(world_seed, cell) * CELL_SIZE
```

- [ ] **Step 6: `scripts/core/SeaNavigation.gd`**

Zastąp `distance` i `travel_time`, dodaj `travel_time_between`:

```gdscript
## Odległość w komórkach między dwoma położeniami wysp (WorldGrid.island_position).
static func distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)
```

```gdscript
## Czas podróży w sekundach między dwoma położeniami. Wiatr działa przez składową wzdłuż kierunku
## podróży - wektora między tymi samymi położeniami - ograniczoną do [0.5, 1.5] prędkości.
## Czysta geometria; skąd biorą się położenia, decyduje travel_time_between.
static func travel_time(a: Vector2, b: Vector2, speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float:
	var d := distance(a, b)
	if d == 0.0:
		return 0.0
	if speed_cells_per_hour <= 0.0:
		return INF
	var dir := (b - a).normalized()
	var factor := clampf(1.0 + WIND_FACTOR * wind.dot(dir), WIND_MIN, WIND_MAX)
	return d / (speed_cells_per_hour * factor) * 3600.0


## Czas podróży między dwiema wyspami świata (ADR 0003): odległość między ich położeniami,
## nie między komórkami. Podgląd dla gracza - czas przybycia liczy i zamraża serwer; położenia
## są tu float32 (Vector2), co daje dokładność ułamka sekundy, nie bit w bit.
static func travel_time_between(world_seed: int, from_cell: Vector2i, to_cell: Vector2i,
		speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float:
	return travel_time(
		WorldGrid.island_position(world_seed, from_cell),
		WorldGrid.island_position(world_seed, to_cell),
		speed_cells_per_hour, wind
	)
```

- [ ] **Step 7: `scenes/autoload/GameState.gd`**

Pod `island_at` dodaj:

```gdscript
## Ziarno świata albo 0, gdy świata jeszcze nie ma. Rysowanie mapy i flot pyta o nie co klatkę,
## także zanim przyjdzie stan, więc zabezpieczenie żyje tu, a nie w każdym wołającym.
func world_seed() -> int:
	return world.seed_val if world != null else 0
```

- [ ] **Step 8: Testy**

```bash
./run_tests.sh test/core
./run_tests.sh test/state
./run_tests.sh
```

Oczekiwane: zielono. `SeaNavigation` nie ma dziś innych wołających niż testy (`grep -rn "SeaNavigation\." scenes scripts tools` pokaże tylko `fleet_speed`, jeśli w ogóle).

- [ ] **Step 9: Artefakt kontraktu**

W `tools/world_parity_dump.gd`, w `_cell_json`, w gałęzi `if island != null:` po `deposit`:

```gdscript
		# ADR 0001, Załącznik, punkt 8: z wersji double, nie z Vector2 (float32).
		var offset := WorldGrid.island_offset_xy(world_seed, cell)
		fields.append("\"offsetX\":%s" % _num(offset[0]))
		fields.append("\"offsetY\":%s" % _num(offset[1]))
```

W `_constants_json` po `depositChance`:

```gdscript
	out += "\"offsetRange\":%s," % _num(WorldGrid.OFFSET_RANGE)
```

Zachowaj stary plik, przegeneruj dwa razy i sprawdź determinizm:

```bash
git show HEAD:contract/world-parity.json > /tmp/ui-polish-parity-old.json
./run_parity.sh
shasum contract/world-parity.json
./run_parity.sh
shasum contract/world-parity.json
```

Oczekiwane: oba przebiegi kończą się kodem 0, bez `SCRIPT ERROR: Assertion failed`, a oba `shasum` są identyczne.

Niezależna weryfikacja w Pythonie, którego parser liczb jest poprawnie zaokrąglany: każde dotychczasowe pole bez zmian, nowe pola tylko tam, gdzie trzeba, i każde przesunięcie równe wzorowi z ADR policzonemu w Pythonie od zera.

```bash
python3 - <<'EOF'
import json
M = 0x7fffffff
def hash_cell(s, x, y):
    h = s & M
    h = (h * 31 + x + 1000003) & M
    h = (h * 31 + y + 1000033) & M
    return ((h ^ (h >> 13)) * 1274126177) & M
def hash01(h):
    return (h % 10007) / 10007.0
R = 0.13
old = json.load(open('/tmp/ui-polish-parity-old.json'))
new = json.load(open('contract/world-parity.json'))
assert new['gridSize'] == old['gridSize']
nc = dict(new['constants'])
assert nc.pop('offsetRange') == R, 'offsetRange'
assert nc == old['constants'], 'zmieniła się inna stała'
assert [w['seed'] for w in new['worlds']] == [w['seed'] for w in old['worlds']]
land = sea = 0
for ow, nw in zip(old['worlds'], new['worlds']):
    s = nw['seed']
    assert len(ow['cells']) == len(nw['cells'])
    for o, n in zip(ow['cells'], nw['cells']):
        where = '%d (%d, %d)' % (s, o['x'], o['y'])
        for k in o:
            assert k in n and n[k] == o[k], 'pole %s zmienione w %s' % (k, where)
        extra = set(n) - set(o)
        if n['isIsland']:
            assert extra == {'offsetX', 'offsetY'}, (where, extra)
            h = hash_cell(s, n['x'], n['y'])
            assert h == n['hash'], where
            ox = (hash01(hash_cell(h, 13, 17)) * 2.0 - 1.0) * R
            oy = (hash01(hash_cell(h, 19, 23)) * 2.0 - 1.0) * R
            assert n['offsetX'] == ox and n['offsetY'] == oy, (where, n['offsetX'], ox, n['offsetY'], oy)
            land += 1
        else:
            assert extra == set(), (where, extra)
            sea += 1
print('PARITY OK: %d komórek lądu z przesunięciem, %d komórek morza bez zmian' % (land, sea))
EOF
```

Oczekiwane: `PARITY OK: ...` i kod 0. Wklej tę linię do raportu. Każdy `AssertionError` to błąd kontraktu, nie powód do poprawiania skryptu.

- [ ] **Step 10: `contract/README.md`**

W pierwszym akapicie zastąp „a dla komórek będących wyspami dodatkowo `radius` i `deposit`” przez:

```
a dla komórek będących wyspami dodatkowo `radius`, `deposit` oraz `offsetX` i `offsetY` -
przesunięcie położenia wyspy w obrębie komórki w ułamkach komórki (ADR 0001, Załącznik, punkt 8;
ADR 0003). W `constants` jest też `offsetRange`
```

Na końcu sekcji „Regeneracja” dopisz:

```
Przy zmianie, która dokłada pola, a nie zmienia geografii (tak jak przy dodaniu `offsetX` i
`offsetY`), porównaj stary i nowy plik niezależnym parserem: każde dotychczasowe pole musi zostać
bit w bit identyczne. Przykład takiej weryfikacji jest w planie
`docs/superpowers/plans/2026-09-10-islanders-ui-v2-polish.md`, Task 6.
```

- [ ] **Step 11: Commit**

```bash
git add scripts/core/WorldGrid.gd scripts/core/SeaNavigation.gd scenes/autoload/GameState.gd tools/world_parity_dump.gd contract/world-parity.json contract/README.md test/core/world_grid_test.gd test/core/sea_navigation_test.gd test/state/game_state_test.gd
git commit -m "Put the island position in the geography contract and measure travel between positions"
```

---

### Task 7: Mapa rysuje i trafia wyspy w ich położeniach; komórka 448 px

**Files:**
- Modify: `scripts/core/WorldGrid.gd` (`CELL_SIZE`), `scenes/views/MapCamera.gd` (`ZOOM_MIN`), `scenes/procedural/FleetRenderer.gd`, `scenes/procedural/IslandGenerator.gd`, `scripts/core/Fleet.gd`, `scenes/views/WorldMap.gd`, `scenes/ui/Sheets.gd`, `tools/smoke_probe.gd`
- Test: `test/core/world_grid_test.gd`, `test/core/fleet_test.gd`, `test/scenes/island_generator_test.gd`, `test/scenes/world_map_test.gd`

**Interfaces:**
- Consumes: `WorldGrid.island_center`, `WorldGrid.OFFSET_RANGE`, `GameState.world_seed()` z Task 6.
- Produces:
  - `WorldGrid.CELL_SIZE := 448.0`, `MapCamera.ZOOM_MIN := 0.15`, `FleetRenderer.DASH := 42.0`, `FleetRenderer.TRIANGLE := 24.0`.
  - `static func IslandGenerator.shallow_outline(seed_val: int, radius: float) -> PackedVector2Array`.
  - `Fleet.position_at(now: float, world_seed: int) -> Vector2`, `Fleet.direction(world_seed: int) -> Vector2` — zamiast wersji bez ziarna.
  - `WorldMap.LABEL_SIZE := Vector2(240, 56)`.

Każde miejsce, które stawiało coś na środku komórki, stawia to teraz na środku wyspy: generatory wysp w chunkach, pierścienie osad (idą za `gen.position`), etykiety, kamera przy wejściu na mapę, trafianie tapnięciem, trasy flot i skok kamery do floty. Wszystkie te miejsca biorą ziarno z `GameState.world_seed()`.

- [ ] **Step 1: Test wspólnego konturu wody**

Dopisz do `test/scenes/island_generator_test.gd` (pomocnik `_generator` jest już w pliku; generator buduje się przy wejściu do drzewa):

```gdscript
## Test prześwitu między wyspami (world_map_test) mierzy shallow_outline(), więc musi to być
## dokładnie ten wielokąt, który build() rysuje jako "Shallow".
func test_shallow_outline_is_what_build_draws() -> void:
	var gen := _generator(Biome.Type.TROPICAL, false)
	var drawn: Polygon2D = gen.get_node("Shallow")
	assert_that(drawn.polygon).is_equal(IslandGenerator.shallow_outline(gen.seed_val, gen.radius))
```

- [ ] **Step 2: Testy geometrii mapy**

W `test/scenes/world_map_test.gd` zmień `_aim`, żeby celował w środek wyspy, nie komórki:

```gdscript
## Ustawia kamerę tak, żeby wskazany punkt ekranu pokrywał się ze środkiem wyspy w komórce.
func _aim(camera: MapCamera, screen_pos: Vector2, cell: Vector2i) -> void:
	var half := camera.get_viewport_rect().size / 2.0
	camera.position = WorldGrid.island_center(WORLD_SEED, cell) - (screen_pos - half) / camera.zoom
```

Popraw komentarz przy `START_POS`: świat 4000 komórek × 448 px ma 1 792 000 px na bok.

Dopisz:

```gdscript
## Najmniejszy dopuszczalny prześwit między obwódkami wody przybrzeżnej sąsiednich wysp.
## Pomiar przy CELL_SIZE 448 i OFFSET_RANGE 0.13 dał ~52 px na ~14 000 par (spec, sekcja 5.2).
const MIN_SHALLOW_GAP := 40.0


func _shallow_at(cell: Vector2i, island: Island) -> PackedVector2Array:
	var center := WorldGrid.island_center(WORLD_SEED, cell)
	var out := PackedVector2Array()
	for p in IslandGenerator.shallow_outline(island.seed_val, island.radius):
		out.append(p + center)
	return out


## Niezmiennik geometrii na tych samych wielokątach, które widać na ekranie: każdą obwódkę
## poszerzamy o połowę prześwitu i żadne dwie sąsiednie (także po przekątnej) nie mogą się
## wtedy przeciąć. Zmniejszenie komórki albo zwiększenie przesunięcia musi przejść ten test.
func test_neighbouring_shallows_keep_a_clear_gap() -> void:
	var inflated := {}
	for y in range(50, 110):
		for x in range(50, 110):
			var cell := Vector2i(x, y)
			var island := WorldGrid.island_at(WORLD_SEED, cell)
			if island != null:
				var grown := Geometry2D.offset_polygon(_shallow_at(cell, island), MIN_SHALLOW_GAP / 2.0, Geometry2D.JOIN_ROUND)
				inflated[cell] = grown[0]
	var pairs := 0
	for cell: Vector2i in inflated:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var other := cell + d
			if not inflated.has(other):
				continue
			pairs += 1
			assert_bool(Geometry2D.intersect_polygons(inflated[cell], inflated[other]).is_empty()) \
				.override_failure_message("obwódki %s i %s bliżej niż %d px" % [cell, other, MIN_SHALLOW_GAP]) \
				.is_true()
	assert_int(pairs).is_greater(100)


## _on_tapped sprawdza wyłącznie wyspę tapniętej komórki. To wystarcza, dopóki dysk trafienia
## największej, najbardziej przesuniętej wyspy mieści się w połowie komórki na każdej osi:
## 0,13 × 448 + 1,1 × 110 = 179 px < 224 px.
func test_tap_disc_never_leaves_its_cell() -> void:
	var reach := WorldGrid.OFFSET_RANGE * WorldGrid.CELL_SIZE + WorldGrid.RADIUS_MAX * IslandGenerator.TAP_RADIUS_FACTOR
	assert_float(reach).is_less(WorldGrid.CELL_SIZE / 2.0)


## Punkt po stronie przesunięcia wyspy, w 95 % promienia trafienia od jej środka, ale dalej od
## środka komórki niż promień trafienia. Liczone od środka komórki - jak przed tą zmianą - byłoby
## pudłem; liczone od środka wyspy jest trafieniem.
func test_tap_measures_from_the_offset_island_centre() -> void:
	_apply_world()
	GameState.apply_settlements([_foreign(FOREIGN_CELL, "Szara Skała")])
	var sheets := _sheets()
	var world_map := _spawn_map(START_POS)
	await _resize_window(PORTRAIT_WINDOW)
	var camera: MapCamera = world_map.camera
	var island := WorldGrid.island_at(WORLD_SEED, FOREIGN_CELL)
	var tap_radius := island.radius * IslandGenerator.TAP_RADIUS_FACTOR
	var centre := WorldGrid.island_center(WORLD_SEED, FOREIGN_CELL)
	var cell_centre := WorldGrid.cell_to_world(FOREIGN_CELL)
	var target := centre + (centre - cell_centre).normalized() * tap_radius * 0.95
	assert_float(target.distance_to(cell_centre)).is_greater(tap_radius)
	camera.position = target   # środek ekranu wskazuje pozycję kamery
	_tap(camera, camera.get_viewport_rect().size / 2.0)
	await await_idle_frame()
	assert_bool(sheets.is_open()).is_true()
	assert_object(sheets.current_sheet()).is_same(sheets.inspect_sheet)


func test_labels_sit_under_their_island_and_do_not_overlap() -> void:
	_apply_world()
	GameState.apply_settlements([_own(HOME_CELL.x, HOME_CELL.y, "Koralowa"), _foreign(FOREIGN_CELL, "Szara Skała")])
	var world_map := _spawn_map(WorldGrid.island_center(WORLD_SEED, HOME_CELL))
	await _settle(world_map)
	var rects: Array[Rect2] = []
	for label: Label in world_map.labels.get_children():
		rects.append(Rect2(label.position, label.size))
		if label.text.begins_with("Koralowa"):
			var centre := WorldGrid.island_center(WORLD_SEED, HOME_CELL)
			assert_float(label.position.x + label.size.x / 2.0).is_equal_approx(centre.x, 0.01)
	assert_int(rects.size()).is_equal(2)
	assert_bool(rects[0].intersects(rects[1])).is_false()


## Etykieta jest węższa niż najmniejsza możliwa odległość środków sąsiadów w poziomie,
## więc dwie etykiety nie mogą się nałożyć niezależnie od tego, które wyspy są zajęte.
func test_label_is_narrower_than_the_closest_possible_neighbour() -> void:
	var closest := WorldGrid.CELL_SIZE * (1.0 - 2.0 * WorldGrid.OFFSET_RANGE)
	assert_float(WORLD_MAP_SCRIPT.LABEL_SIZE.x).is_less(closest)
```

- [ ] **Step 3: Testy floty i siatki**

W `test/core/fleet_test.gd` dodaj stałą i zastąp `test_position_at_midpoint`:

```gdscript
const SEED := FixtureCells.WORLD_SEED
```

```gdscript
func test_position_at_midpoint() -> void:
	var f := Fleet.from_json(_json())
	var expected := WorldGrid.island_center(SEED, Vector2i(0, 0)).lerp(WorldGrid.island_center(SEED, Vector2i(4, 0)), 0.5)
	assert_that(f.position_at(DEPART + 1800.0, SEED)).is_equal(expected)


## Trasa zaczyna się i kończy na wyspach, nie na środkach komórek obok nich.
func test_route_starts_and_ends_on_the_islands() -> void:
	var d := _json()
	d["from"] = {"x": FixtureCells.FOREIGN.x, "y": FixtureCells.FOREIGN.y}
	d["to"] = {"x": FixtureCells.HOME.x, "y": FixtureCells.HOME.y}
	var f := Fleet.from_json(d)
	var start := WorldGrid.island_center(SEED, FixtureCells.FOREIGN)
	var end := WorldGrid.island_center(SEED, FixtureCells.HOME)
	assert_that(f.position_at(DEPART - 10.0, SEED)).is_equal(start)
	assert_that(f.position_at(ARRIVE + 10.0, SEED)).is_equal(end)
	assert_that(f.direction(SEED)).is_equal((end - start).normalized())
```

W `test/core/world_grid_test.gd`, w `test_cell_world_roundtrip`, środek komórki (0, 0) to teraz połowa 448:

```gdscript
	assert_that(
		WorldGrid.cell_to_world(Vector2i(0, 0))
	).is_equal(Vector2(224, 224))
```

- [ ] **Step 4: Uruchom po jednym, oczekuj porażek**

```bash
./run_tests.sh test/scenes/island_generator_test.gd
./run_tests.sh test/core/fleet_test.gd
./run_tests.sh test/core/world_grid_test.gd
./run_tests.sh test/scenes/world_map_test.gd
```

Oczekiwane: brak `shallow_outline`, zła liczba argumentów `position_at`, `Vector2(128, 128)` zamiast 224, brak `LABEL_SIZE`; przy komórce 256 `test_neighbouring_shallows_keep_a_clear_gap` pada na nałożeniach (pomiar: 174 nałożenia na 7518 par), a `test_tap_measures_from_the_offset_island_centre` pada, bo trafianie liczy od środka komórki. Zbierz RED po jednym teście.

- [ ] **Step 5: Stałe**

`scripts/core/WorldGrid.gd`:

```gdscript
## Rozmiar komórki w pikselach mapy. Rendering, nie kontrakt (backend pracuje w komórkach).
## 448 zamiast 256 rozsuwa wyspy; próg prześwitu pilnuje world_map_test.
const CELL_SIZE := 448.0
```

`scenes/views/MapCamera.gd`: `const ZOOM_MIN := 0.15` z komentarzem „przy komórce 448 najszersze przybliżenie pokazuje ~16 komórek, jak wcześniej przy 256 i 0,25”.

`scenes/procedural/FleetRenderer.gd`: `const DASH := 42.0` i `const TRIANGLE := 24.0` z komentarzem „× 1,75 wobec komórki 256, żeby trasa i znacznik nie zmalały wobec odległości”.

- [ ] **Step 6: `IslandGenerator.shallow_outline`**

W `scenes/procedural/IslandGenerator.gd`, pod `contains`:

```gdscript
## Kontur wody przybrzeżnej w układzie wyspy - ten sam, który build() rysuje jako "Shallow".
## Statyczny, żeby test prześwitu między wyspami mierzył dokładnie to, co widać na mapie.
static func shallow_outline(seed_val: int, radius: float) -> PackedVector2Array:
	return CoastlineGenerator.scaled(CoastlineGenerator.generate(seed_val, radius, POINTS), SHALLOW_SCALE)
```

`build()` zostaje przy `CoastlineGenerator.scaled(_coast, SHALLOW_SCALE)`, bo `_coast` i tak jest mu potrzebny do piasku i zatoki; test ze Step 1 pilnuje, że oba wyniki są identyczne.

- [ ] **Step 7: `Fleet` i jego konsumenci**

`scripts/core/Fleet.gd`, zastąp `position_at` i `direction`:

```gdscript
## Pozycja na mapie w chwili now, między środkami wysp startu i celu (WorldGrid.island_center),
## żeby trasa zaczynała się i kończyła na wyspach, a nie obok nich. Flota zna identyfikator
## świata, ale nie jego ziarno, więc podaje je wołający (GameState.world_seed()).
func position_at(now: float, world_seed: int) -> Vector2:
	return WorldGrid.island_center(world_seed, from).lerp(WorldGrid.island_center(world_seed, to), progress(now))


func direction(world_seed: int) -> Vector2:
	return (WorldGrid.island_center(world_seed, to) - WorldGrid.island_center(world_seed, from)).normalized()
```

`scenes/procedural/FleetRenderer.gd`, w `_draw()`:

```gdscript
	var now := TimeUtil.now()
	var world_seed := GameState.world_seed()
	var font := ThemeDB.fallback_font
	for f: Fleet in _fleets:
		if f.is_arrived(now):
			continue
		var a := WorldGrid.island_center(world_seed, f.from)
		var b := WorldGrid.island_center(world_seed, f.to)
		...
		var pos := f.position_at(now, world_seed)
		var dir := f.direction(world_seed)
```

`scenes/ui/Sheets.gd`, w `_on_fleet_tapped`:

```gdscript
	SceneManager.show_world_map_at(fleet.position_at(TimeUtil.now(), GameState.world_seed()))
```

- [ ] **Step 8: `scenes/views/WorldMap.gd`**

Dodaj stałą obok `LABEL_FONT_SIZE`:

```gdscript
## Etykieta osady pod wyspą. Szerokość musi zostać mniejsza niż najmniejsza odległość środków
## sąsiadów (CELL_SIZE × (1 − 2 × OFFSET_RANGE) = 332 px) - pilnuje tego world_map_test.
const LABEL_SIZE := Vector2(240, 56)
```

W `_ready()`:

```gdscript
	elif GameState.active_settlement != null:
		camera.position = WorldGrid.island_center(GameState.world_seed(), GameState.active_settlement.coord)
```

W `_spawn_chunk()`:

```gdscript
			gen.position = WorldGrid.island_center(GameState.world_seed(), cell)
```

W `_rebuild_labels()`:

```gdscript
		label.size = LABEL_SIZE
		label.position = WorldGrid.island_center(GameState.world_seed(), s.coord) \
			+ Vector2(-LABEL_SIZE.x / 2.0, radius * 1.3 + 4)
```

W `_on_tapped()`:

```gdscript
	# Od środka wyspy, nie komórki. Sąsiednich komórek nie trzeba sprawdzać: dysk trafienia
	# nigdy nie wychodzi poza własną komórkę (world_map_test, test_tap_disc_never_leaves_its_cell).
	var local := world_pos - WorldGrid.island_center(GameState.world_seed(), cell)
```

- [ ] **Step 9: Smoke probe**

W `tools/smoke_probe.gd` zamień trzy ustawienia kamery przed tapnięciem wyspy (`FOREIGN`, `DEPOSIT`, `HOME`) z `WorldGrid.cell_to_world(...)` na:

```gdscript
			_map().camera.position = WorldGrid.island_center(GameState.world_seed(), FixtureCells.FOREIGN)
```

(analogicznie `FixtureCells.DEPOSIT` i `FixtureCells.HOME`), a sprawdzenie pozycji floty na:

```gdscript
			var dist: float = _map().camera.position.distance_to(incoming.position_at(TimeUtil.now(), GameState.world_seed()))
```

- [ ] **Step 10: Testy, smoke i zrzut mapy**

```bash
./run_tests.sh
./run_smoke.sh
grep -rn "position_at(\|direction(" scenes scripts tools test | grep -v "world_seed\|SEED\|func "
mkdir -p /tmp/ui-polish-task7
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 1080x1920 res://tools/Capture.tscn -- /tmp/ui-polish-task7 2>&1 | grep -E 'CAPTURE|SCRIPT ERROR'
```

Oczekiwane: zielono; `grep` nic nie znajduje (każde wywołanie podaje ziarno); sonda zapisuje `03-mapa.png`, na którym wyspy nie stoją w równych rzędach. Obejrzyj ten plik przed commitem.

- [ ] **Step 11: Commit**

```bash
git add scripts/core/WorldGrid.gd scenes/views/MapCamera.gd scenes/procedural/FleetRenderer.gd scenes/procedural/IslandGenerator.gd scripts/core/Fleet.gd scenes/views/WorldMap.gd scenes/ui/Sheets.gd tools/smoke_probe.gd test/core/world_grid_test.gd test/core/fleet_test.gd test/scenes/island_generator_test.gd test/scenes/world_map_test.gd
git commit -m "Draw and hit islands at their contract positions on a wider map grid"
```

---

### Task 8: Plakietka powrotu na mapie jako sama ikona

**Files:**
- Modify: `scenes/views/WorldMap.tscn` (`BackPlaque`), `scenes/views/WorldMap.gd` (`_style_ui`)
- Test: `test/scenes/world_map_test.gd`

**Interfaces:**
- Znika `WorldMap.BACK_WIDTH`. `back_plaque` zostaje pod tą samą nazwą i nadal woła `SceneManager.show_island_detail()`.

Plakietka „OSADA” miała `px(110)` szerokości i zasłaniała wyspę pod paskiem. Strzałka powrotu wystarcza; przycisk staje się kwadratem `px(46)`, jak przyciski doku i przybliżania.

- [ ] **Step 1: Test**

Dopisz do `test/scenes/world_map_test.gd`:

```gdscript
func test_back_plaque_is_a_square_icon_button() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	var back: Button = world_map.back_plaque
	var tool := float(MedievalTheme.px(WORLD_MAP_SCRIPT.TOOL))
	assert_str(back.text).is_empty()
	assert_str(back.tooltip_text).is_equal("Wróć do osady")
	assert_that(back.size).is_equal(Vector2(tool, tool))
	var icon: Icon = back.get_node("Icon")
	assert_str(String(icon.kind)).is_equal("back")
	assert_float(icon.anchor_right).is_equal(1.0)
	assert_bool("BACK_WIDTH" in WORLD_MAP_SCRIPT.get_script_constant_map()).is_false()
```

- [ ] **Step 2: Uruchom, oczekuj porażki**

```bash
./run_tests.sh test/scenes/world_map_test.gd
```

Oczekiwane: pada na `back.text` („OSADA”).

- [ ] **Step 3: Implementacja**

W `scenes/views/WorldMap.tscn`, w węźle `BackPlaque`, usuń linie `text = "OSADA"` i `alignment = 2`, a dodaj `tooltip_text = "Wróć do osady"`.

W `scenes/views/WorldMap.gd` usuń `const BACK_WIDTH := 110.0`, a w `_style_ui()` zastąp całe ustawianie `back_plaque` i jego ikony:

```gdscript
	var tool := MedievalTheme.px(TOOL)
	# Sama strzałka, jak przyciski doku i przybliżania: napis zasłaniał wyspę pod paskiem.
	back_plaque.custom_minimum_size = Vector2(tool, tool)
	Icon.into_button(back_plaque, &"back", MedievalTheme.CREAM, MedievalTheme.px(12))
```

- [ ] **Step 4: Testy i smoke**

```bash
./run_tests.sh test/scenes/world_map_test.gd
./run_smoke.sh
```

Oczekiwane: zielono; smoke nadal przechodzi krok „plakietka OSADA wraca do osady”, bo tapie środek przycisku.

- [ ] **Step 5: Commit**

```bash
git add scenes/views/WorldMap.tscn scenes/views/WorldMap.gd test/scenes/world_map_test.gd
git commit -m "Shrink the map's back plaque to an icon so it stops covering islands"
```

---

### Task 9: Tapnięcie wyspy zawsze ją ogląda; wejście do osady jawną akcją w arkuszu

**Files:**
- Modify: `scenes/views/WorldMap.gd` (`_on_tapped`), `scenes/ui/InspectSheet.tscn`, `scenes/ui/InspectSheet.gd`, `scenes/ui/Sheets.gd`, `tools/smoke_probe.gd` (fazy 5-8)
- Test: `test/scenes/inspect_sheet_test.gd`, `test/scenes/sheets_test.gd`, `test/scenes/world_map_test.gd`

**Interfaces:**
- Consumes: `GameState.world_seed()` (Task 6), `WorldGrid.island_center` (Task 6).
- Produces: `InspectSheet.enter_settlement_requested(coord: Vector2i)` (sygnał), `InspectSheet.action_button: Button`, `InspectSheet.ENTER_TEXT := "PRZEJDŹ DO OSADY"`, `InspectSheet.RETURN_TEXT := "WRÓĆ DO OSADY"`, `Sheets._on_enter_settlement_requested(coord: Vector2i)`.

Glosariusz, **Active Settlement**: osada aktywna zmienia się tylko przez świadome przełączenie, nigdy przez samo obejrzenie wyspy. Dziś tapnięcie własnej osady na mapie od razu ją aktywuje i przerzuca do widoku osady, więc nie da się wskazać własnej osady jako celu transportu. Po zmianie mapa zawsze tylko ogląda; przełączenie żyje w jednym miejscu, w akcji arkusza.

| Tryb arkusza | Podpis | Widoczne w `Body` | Akcja |
|---|---|---|---|
| cudza osada | `(x, y) · gracz 9` (Task 10 zmieni na pseudonim) | `PublicLabel` | brak |
| wyspa niczyja | `(x, y) · wyspa niczyja` | `DepositHeader`+`DepositRow` albo `EmptyLabel` | brak |
| własna osada nieaktywna | `(x, y) · twoja osada` | nic | „PRZEJDŹ DO OSADY”: aktywuje i przełącza widok |
| własna osada aktywna | `(x, y) · twoja osada` | nic | „WRÓĆ DO OSADY”: tylko przełącza widok |

- [ ] **Step 1: Testy arkusza**

W `test/scenes/inspect_sheet_test.gd` rozszerz `before_test` o dwie własne osady (cudza zostaje):

```gdscript
const HOME := FixtureCells.HOME
const OWN_SECOND := FixtureCells.OWN_SECOND


func _own(cell: Vector2i, settlement_name: String) -> Dictionary:
	return {"x": cell.x, "y": cell.y, "ownerId": 7, "name": settlement_name, "resources": {}}


func before_test() -> void:
	GameState.reset()
	GameState.apply_world(FixtureCells.world_json())
	GameState.apply_settlements([
		{"x": FOREIGN.x, "y": FOREIGN.y, "ownerId": 9, "name": "Szara Skała"},
		_own(HOME, "Koralowa"),
		_own(OWN_SECOND, "Popielna"),
	])
	GameState.set_active_settlement(HOME)
```

Dopisz:

```gdscript
func test_own_inactive_settlement_offers_to_enter_it() -> void:
	var s := _sheet()
	assert_bool(s.open(OWN_SECOND)).is_true()
	assert_str(s.name_label.text).is_equal("Popielna")
	assert_str(s.subtitle.text).is_equal("(%d, %d) · twoja osada" % [OWN_SECOND.x, OWN_SECOND.y])
	assert_bool(s.action_button.visible).is_true()
	assert_str(s.action_button.text).is_equal(InspectSheet.ENTER_TEXT)
	assert_bool(s.public_label.visible).is_false()
	assert_bool(s.deposit_header.visible).is_false()
	assert_bool(s.empty_label.visible).is_false()


func test_own_active_settlement_offers_to_return() -> void:
	var s := _sheet()
	assert_bool(s.open(HOME)).is_true()
	assert_str(s.action_button.text).is_equal(InspectSheet.RETURN_TEXT)
	assert_bool(s.action_button.visible).is_true()


func test_action_hides_again_for_a_foreign_island() -> void:
	var s := _sheet()
	s.open(HOME)
	s.open(FOREIGN)
	assert_bool(s.action_button.visible).is_false()
	s.open(EMPTY_WITH_DEPOSIT)
	assert_bool(s.action_button.visible).is_false()


func test_action_emits_the_inspected_coord() -> void:
	var s := _sheet()
	var got: Array = []
	s.enter_settlement_requested.connect(func(c: Vector2i) -> void: got.append(c))
	s.open(OWN_SECOND)
	s.action_button.pressed.emit()
	assert_that(got).is_equal([OWN_SECOND])
```

- [ ] **Step 2: Testy zarządcy arkuszy**

W `test/scenes/sheets_test.gd` dodaj kontener widoków dla `SceneManager` (autoload; sprzątanie jak w `scene_manager_test.gd`):

```gdscript
var _container: Node = null


func before_test() -> void:
	GameState.reset()
	_container = Node.new()
	add_child(_container)
	SceneManager.register_container(_container)


func after_test() -> void:
	# Najpierw zrywamy referencje autoloadu, potem zwalniamy węzły.
	SceneManager._current = null
	SceneManager.current_view = ""
	SceneManager.register_container(null)
	SceneManager.map_camera_state.clear()
	if is_instance_valid(_container):
		_container.queue_free()
	_container = null
	GameState.reset()


func _two_own_settlements() -> void:
	GameState.apply_world(FixtureCells.world_json())
	GameState.apply_settlements([
		{"x": FixtureCells.HOME.x, "y": FixtureCells.HOME.y, "ownerId": 7, "name": "Koralowa", "resources": {}},
		{"x": FixtureCells.OWN_SECOND.x, "y": FixtureCells.OWN_SECOND.y, "ownerId": 7, "name": "Popielna", "resources": {}},
	])
	GameState.set_active_settlement(FixtureCells.HOME)


func test_enter_settlement_activates_it_and_switches_to_the_settlement_view() -> void:
	_two_own_settlements()
	var s := _sheets()
	s.open_inspect(FixtureCells.OWN_SECOND)
	s.inspect_sheet.action_button.pressed.emit()
	assert_that(GameState.active_settlement.coord).is_equal(FixtureCells.OWN_SECOND)
	assert_str(SceneManager.current_view).is_equal(SceneManager.VIEW_ISLAND_DETAIL)
	assert_bool(s.is_open()).is_false()


## „Wróć do osady” nie przełącza osady aktywnej na nowo: bez tego każdy powrót przebudowywałby
## pasek i widok osady, jakby gracz wybrał inną osadę.
func test_return_to_the_active_settlement_only_switches_the_view() -> void:
	_two_own_settlements()
	var s := _sheets()
	var changes := [0]
	var on_change := func() -> void: changes[0] += 1
	GameState.active_settlement_changed.connect(on_change)
	s.open_inspect(FixtureCells.HOME)
	s.inspect_sheet.action_button.pressed.emit()
	# GameState to autoload: lambda zostałaby podpięta do następnych testów.
	GameState.active_settlement_changed.disconnect(on_change)
	assert_int(changes[0]).is_equal(0)
	assert_that(GameState.active_settlement.coord).is_equal(FixtureCells.HOME)
	assert_str(SceneManager.current_view).is_equal(SceneManager.VIEW_ISLAND_DETAIL)
```

- [ ] **Step 3: Testy mapy**

W `test/scenes/world_map_test.gd` dopisz:

```gdscript
## Glosariusz, Active Settlement: obejrzenie wyspy nigdy nie zmienia osady aktywnej.
## Dotyczy także własnej osady - inaczej nie dałoby się jej wskazać jako celu transportu.
func test_tapping_an_own_settlement_inspects_it_without_activating() -> void:
	_apply_world()
	GameState.apply_settlements([_own(HOME_CELL.x, HOME_CELL.y, "Koralowa"), _own(FixtureCells.OWN_SECOND.x, FixtureCells.OWN_SECOND.y, "Popielna")])
	GameState.set_active_settlement(HOME_CELL)
	var sheets := _sheets()
	var world_map := _spawn_map(START_POS)
	await _resize_window(PORTRAIT_WINDOW)
	var camera: MapCamera = world_map.camera
	var view_before := SceneManager.current_view
	var centre := camera.get_viewport_rect().size / 2.0
	for cell in [FixtureCells.OWN_SECOND, HOME_CELL]:
		_aim(camera, centre, cell)
		_tap(camera, centre)
		await await_idle_frame()
		assert_bool(sheets.is_open()).override_failure_message("tap %s nie otworzył arkusza" % cell).is_true()
		assert_object(sheets.current_sheet()).is_same(sheets.inspect_sheet)
		assert_that(GameState.active_settlement.coord).is_equal(HOME_CELL)
		assert_str(SceneManager.current_view).is_equal(view_before)
		assert_that(GameState.inspected_coord).is_equal(cell)
```

- [ ] **Step 4: Uruchom po jednym, oczekuj porażek**

```bash
./run_tests.sh test/scenes/inspect_sheet_test.gd
./run_tests.sh test/scenes/sheets_test.gd
./run_tests.sh test/scenes/world_map_test.gd
```

Oczekiwane: brak `action_button` i `ENTER_TEXT`; tapnięcie własnej osady zmienia dziś osadę aktywną i nie otwiera arkusza.

- [ ] **Step 5: `scenes/ui/InspectSheet.tscn`**

Na końcu pliku, po `EmptyLabel`:

```
[node name="ActionButton" type="Button" parent="SheetMargin/Body"]
visible = false
layout_mode = 2
text = "PRZEJDŹ DO OSADY"
theme_type_variation = &"Primary"
```

- [ ] **Step 6: `scenes/ui/InspectSheet.gd`**

Komentarz nagłówkowy, sygnał, stałe i pola:

```gdscript
## Arkusz oglądanej wyspy nad mapą: cudza osada (dane publiczne), wyspa niczyja (znalezisko)
## albo własna osada (dane publiczne i akcja wejścia). Dane prywatne własnej osady są o jedno
## tapnięcie dalej, w widoku osady - arkusz ich nie powiela.

signal close_requested
## Jedyna droga zmiany osady aktywnej z mapy (glosariusz: Active Settlement).
signal enter_settlement_requested(coord: Vector2i)

const ENTER_TEXT := "PRZEJDŹ DO OSADY"
const RETURN_TEXT := "WRÓĆ DO OSADY"
const ACTION_HEIGHT := 48.0
```

Pod ostatnim `@onready` dodaj:

```gdscript
@onready var action_button: Button = $SheetMargin/Body/ActionButton

var _coord: Vector2i = Coord.NONE
```

W `_ready()` dopisz:

```gdscript
	action_button.custom_minimum_size.y = MedievalTheme.px(ACTION_HEIGHT)
	action_button.pressed.connect(func() -> void: enter_settlement_requested.emit(_coord))
```

W `open()`, po wyczyszczeniu chipów znaleziska, ustaw współrzędne i schowaj akcję, a przed gałęzią cudzej osady wstaw gałąź własnej:

```gdscript
	_coord = coord
	action_button.hide()
	if s != null and s.is_own:
		name_label.text = s.name
		subtitle.text = "(%d, %d) · twoja osada" % [coord.x, coord.y]
		public_label.hide()
		deposit_header.hide()
		deposit_row.hide()
		empty_label.hide()
		var active := GameState.active_settlement
		action_button.text = RETURN_TEXT if active != null and active.coord == coord else ENTER_TEXT
		action_button.show()
		return true
	if s != null:
		...   # gałąź cudzej osady bez zmian
```

- [ ] **Step 7: `scenes/ui/Sheets.gd`**

W `_ready()`, obok `fleets_sheet.fleet_tapped.connect(...)`:

```gdscript
	inspect_sheet.enter_settlement_requested.connect(_on_enter_settlement_requested)
```

Pod `_on_fleet_tapped`:

```gdscript
## Akcja arkusza własnej osady. Przełącza osadę aktywną tylko wtedy, gdy to inna osada -
## „Wróć do osady” nie ma przebudowywać paska ani widoku. Zmiana widoku zamknie warstwę od razu.
func _on_enter_settlement_requested(coord: Vector2i) -> void:
	close()
	var active := GameState.active_settlement
	if active == null or active.coord != coord:
		if not GameState.set_active_settlement(coord):
			return
	SceneManager.show_island_detail()
```

- [ ] **Step 8: `scenes/views/WorldMap.gd`, `_on_tapped`**

Zastąp końcówkę funkcji (od `var s := GameState.settlement_at(cell)`) samym oglądaniem:

```gdscript
	# Tapnięcie zawsze ogląda, także własną i aktywną osadę; osadę aktywną zmienia wyłącznie
	# akcja w arkuszu (glosariusz: Active Settlement).
	GameState.inspect(cell)
	var sheets := get_tree().get_first_node_in_group("sheets")
	if sheets != null:
		sheets.open_inspect(cell)
```

- [ ] **Step 9: Smoke probe, fazy 5-8**

W `tools/smoke_probe.gd` dodaj pomocnika pod `_settled()`:

```gdscript
## Prawda, gdy arkusz jest otwarty i skończył wjeżdżać. Tapnięcie przycisku w arkuszu w trakcie
## animacji trafiałoby w miejsce, z którego przycisk właśnie odjeżdża.
func _opened() -> bool:
	var sheets := _sheets()
	return sheets.is_open() and (sheets._tween == null or not sheets._tween.is_running())
```

Zastąp blok od komentarza `# --- Tap własnej osady wraca do widoku osady. ---` do linii `elif _frame == _gate + 7:` (wyłącznie) tym:

```gdscript
	# --- Tap własnej, aktywnej osady tylko ją ogląda; wejście to jawna akcja w arkuszu. ---
	elif _phase == 5 and _settled():
		_gate = _frame
		_phase = 6
		_map().camera.position = WorldGrid.island_center(GameState.world_seed(), FixtureCells.HOME)
		_mouse_press(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
	elif _phase == 6:
		if _frame == _gate + 2:
			_mouse_release(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		elif _frame == _gate + 5:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.current_sheet() == sheets.inspect_sheet, "tap własnej osady otwiera arkusz")
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "tap własnej osady zostawia mapę")
			_check(GameState.active_settlement.name == "Koralowa", "tap nie zmienia osady aktywnej")
			_check(sheets.inspect_sheet.action_button.text == InspectSheet.RETURN_TEXT, "arkusz aktywnej osady proponuje powrót")
			_phase = 7   # przycisk tapiemy dopiero, gdy arkusz skończy wjeżdżać (patrz _opened())
	elif _phase == 7 and _opened():
		_gate = _frame
		_phase = 8
		_tap_control(_sheets().inspect_sheet.action_button)
	elif _phase == 8:
		if _frame == _gate + 5:
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "WRÓĆ DO OSADY przełącza do widoku osady")
			_check(not _sheets().is_open(), "zmiana widoku zamyka arkusze")
			_check(GameState.active_settlement.name == "Koralowa", "powrót nie zmienia osady aktywnej")
```

Pozostałe kroki dawnej fazy 6 (`_gate + 7` do `_gate + 24`: arkusz flot, tap w kartę floty, resync, powrót plakietką) przenieś bez zmian treści do gałęzi `elif _phase == 8:`, jako kolejne `elif _frame == _gate + N:` po kroku `_gate + 5`. Ich odstępy liczą się teraz od tapnięcia akcji, co jest bezpieczne z tego samego powodu co wcześniej: zmiana widoku zamyka arkusze od razu, bez animacji. Zaktualizuj też komentarz o harmonogramie przy `_phase`/`_gate` na górze pliku, jeśli wymienia numery faz.

- [ ] **Step 10: Testy i smoke**

```bash
./run_tests.sh
./run_smoke.sh
```

Oczekiwane: zielono; smoke drukuje nowe linie „tap własnej osady otwiera arkusz”, „tap nie zmienia osady aktywnej” i „WRÓĆ DO OSADY przełącza do widoku osady”, a kończy się `SMOKE PASSED`.

- [ ] **Step 11: Commit**

```bash
git add scenes/views/WorldMap.gd scenes/ui/InspectSheet.tscn scenes/ui/InspectSheet.gd scenes/ui/Sheets.gd tools/smoke_probe.gd test/scenes/inspect_sheet_test.gd test/scenes/sheets_test.gd test/scenes/world_map_test.gd
git commit -m "Make map taps only inspect and move entering a settlement to an explicit sheet action"
```

---

### Task 10: Pseudonim właściciela zamiast numeru konta

**Files:**
- Modify: `scripts/core/Settlement.gd`, `scripts/core/Fleet.gd`, `fixtures/settlements.json`, `fixtures/fleets.json`, `scenes/views/WorldMap.gd` (`_rebuild_labels`), `scenes/ui/InspectSheet.gd`, `scenes/ui/FleetCard.gd`, `tools/smoke_probe.gd` (jedno sprawdzenie), `docs/superpowers/specs/2026-09-07-islanders-client-skeleton-design.md` (4.2, 4.3)
- Test: `test/core/settlement_test.gd`, `test/core/fleet_test.gd`, `test/scenes/inspect_sheet_test.gd`, `test/scenes/fleet_card_test.gd`, `test/scenes/world_map_test.gd`

**Interfaces:**
- Produces: `Settlement.UNKNOWN_OWNER := "nieznany gracz"`, `Settlement.owner_name: String`, `static func Settlement.parse_owner_name(d: Dictionary) -> String`, `Fleet.owner_name: String` (domyślnie `Settlement.UNKNOWN_OWNER`). `owner_id` zostaje w modelu — służy do `is_own` i nie jest nigdzie wyświetlany.

Glosariusz: pseudonim (`ownerName`) to jedyna informacja o koncie, jaką widzą inni gracze. Backend już go wysyła w publicznym widoku osady i w widoku floty. Brak albo pusty pseudonim daje „nieznany gracz”, nigdy numer; wartość zapasowa ustawia się przy parsowaniu, więc miejsca wyświetlania jej nie powielają.

- [ ] **Step 1: Testy modelu**

Dopisz do `test/core/settlement_test.gd`:

```gdscript
func test_owner_name_is_read_from_json() -> void:
	var s := Settlement.from_json({"x": 1, "y": 2, "ownerId": 9, "ownerName": "Kormoran", "name": "Obca"}, Biome.Type.VOLCANIC)
	assert_str(s.owner_name).is_equal("Kormoran")


## Bez pseudonimu nigdy nie wracamy do numeru konta - glosariusz: Nickname.
func test_missing_or_empty_owner_name_is_unknown_player() -> void:
	var missing := Settlement.from_json({"x": 1, "y": 2, "ownerId": 9, "name": "Obca"}, Biome.Type.VOLCANIC)
	var empty := Settlement.from_json({"x": 1, "y": 2, "ownerId": 9, "ownerName": "", "name": "Obca"}, Biome.Type.VOLCANIC)
	assert_str(missing.owner_name).is_equal(Settlement.UNKNOWN_OWNER)
	assert_str(empty.owner_name).is_equal(Settlement.UNKNOWN_OWNER)
```

Dopisz do `test/core/fleet_test.gd`:

```gdscript
func test_owner_name_is_read_with_unknown_fallback() -> void:
	var d := _json()
	d["ownerName"] = "Kormoran"
	assert_str(Fleet.from_json(d).owner_name).is_equal("Kormoran")
	assert_str(Fleet.from_json(_json()).owner_name).is_equal(Settlement.UNKNOWN_OWNER)
```

- [ ] **Step 2: Testy miejsc wyświetlania**

`test/scenes/inspect_sheet_test.gd`: w `before_test` dodaj `"ownerName": "Kormoran"` do słownika cudzej osady, a w `test_foreign_settlement_shows_public_data` zmień oczekiwany podpis:

```gdscript
	assert_str(s.subtitle.text).is_equal("(%d, %d) · Kormoran" % [FOREIGN.x, FOREIGN.y])
	assert_bool(s.subtitle.text.contains("9")).is_false()
```

`test/scenes/fleet_card_test.gd`: dodaj `"ownerName": "Kormoran"` do słownika w `_fleet()`, a w `test_foreign_attack_hides_details_and_is_red`:

```gdscript
	assert_str(c.composition.text).is_equal("Kormoran · szczegóły niewidoczne")
```

`test/scenes/world_map_test.gd`: w `_foreign()` dodaj `"ownerName": "Kormoran"` i dopisz:

```gdscript
func test_labels_show_nickname_for_others_and_you_for_own() -> void:
	_apply_world()
	GameState.apply_settlements([_own(HOME_CELL.x, HOME_CELL.y, "Koralowa"), _foreign(FOREIGN_CELL, "Szara Skała")])
	var world_map := _spawn_map(WorldGrid.island_center(WORLD_SEED, HOME_CELL))
	await _settle(world_map)
	var texts: Array[String] = []
	for label: Label in world_map.labels.get_children():
		texts.append(label.text)
	texts.sort()
	assert_that(texts).is_equal(["Koralowa\nTy", "Szara Skała\nKormoran"])
```

- [ ] **Step 3: Uruchom po jednym, oczekuj porażek**

```bash
./run_tests.sh test/core/settlement_test.gd
./run_tests.sh test/core/fleet_test.gd
./run_tests.sh test/scenes/inspect_sheet_test.gd
./run_tests.sh test/scenes/fleet_card_test.gd
./run_tests.sh test/scenes/world_map_test.gd
```

Oczekiwane: brak `owner_name` i `UNKNOWN_OWNER`; teksty zawierają „gracz 9”.

- [ ] **Step 4: Model**

`scripts/core/Settlement.gd`, nad polami:

```gdscript
## Tekst w miejsce pseudonimu, gdy serwer go nie przysłał. Nigdy numer konta - glosariusz: Nickname.
const UNKNOWN_OWNER := "nieznany gracz"
```

pole pod `owner_id`:

```gdscript
## Pseudonim właściciela (ownerName) - jedyna informacja o koncie widoczna dla innych graczy.
var owner_name: String = UNKNOWN_OWNER
```

i w `from_json`, pod `s.owner_id = ...`:

```gdscript
	s.owner_name = parse_owner_name(d)
```

z funkcją statyczną pod `from_json`:

```gdscript
## ownerName z JSON osady albo floty; brak albo pusty daje UNKNOWN_OWNER.
static func parse_owner_name(d: Dictionary) -> String:
	var raw := str(d.get("ownerName", ""))
	return UNKNOWN_OWNER if raw.is_empty() else raw
```

`scripts/core/Fleet.gd`, pole pod `owner_id`:

```gdscript
## Pseudonim właściciela; dla nadchodzącej cudzej floty jedyne, co o nim wiemy.
var owner_name: String = Settlement.UNKNOWN_OWNER
```

i w `from_json`, pod `f.owner_id = ...`:

```gdscript
	f.owner_name = Settlement.parse_owner_name(d)
```

- [ ] **Step 5: Fixtures**

`fixtures/settlements.json`: dopisz `"ownerName": "Mewa"` obok `"ownerId": 7` w Koralowej i Popielnej oraz `"ownerName": "Kormoran"` obok `"ownerId": 9` w Szarej Skale.
`fixtures/fleets.json`: `"ownerName": "Mewa"` we flotach `f1` i `f2`, `"ownerName": "Kormoran"` we flocie `f3`.

- [ ] **Step 6: Miejsca wyświetlania**

`scenes/views/WorldMap.gd`, `_rebuild_labels()`:

```gdscript
		label.text = "%s\n%s" % [s.name, "Ty" if s.is_own else s.owner_name]
```

`scenes/ui/InspectSheet.gd`, gałąź cudzej osady:

```gdscript
		subtitle.text = "(%d, %d) · %s" % [coord.x, coord.y, s.owner_name]
```

`scenes/ui/FleetCard.gd`, `refresh()`:

```gdscript
	composition.text = _composition(f) if f.is_own(player_id) else "%s · szczegóły niewidoczne" % f.owner_name
```

`tools/smoke_probe.gd`, sprawdzenie arkusza inspekcji:

```gdscript
			_check(sheets.inspect_sheet.subtitle.text.contains("Kormoran"), "arkusz inspekcji pokazuje pseudonim właściciela")
```

W `scenes/ui/InspectSheet.tscn` zmień tekst `PublicLabel` na „Dane publiczne: nazwa i pseudonim właściciela.” — tak samo brzmi to w glosariuszu.

- [ ] **Step 7: Specyfikacja szkieletu**

W `docs/superpowers/specs/2026-09-07-islanders-client-skeleton-design.md`, 4.2: w przykładzie dopisz `"ownerName": "Mewa",` obok `"ownerId": 7`, a zdanie o danych publicznych zmień na „Cudza osada (dane publiczne) ma tylko `world`, `x`, `y`, `ownerId`, `ownerName`, `name`. Klient pokazuje innym graczom wyłącznie `ownerName` (glosariusz: Nickname); `ownerId` służy tylko do rozpoznania osady własnej.” W 4.3: `"ownerName": "Mewa",` w przykładzie i „Nadchodząca cudza flota ma `ownerId`, `ownerName`, `mission`, `from`, `to`, `arriveAt`, bez `ships` i `cargo`.”

- [ ] **Step 8: Testy, smoke i kontrola**

```bash
./run_tests.sh
./run_smoke.sh
grep -rn "gracz %d\|owner_id\]" scenes scripts tools
```

Oczekiwane: zielono; `grep` nic nie znajduje — żaden tekst na ekranie nie składa się z numeru konta.

- [ ] **Step 9: Commit**

```bash
git add scripts/core/Settlement.gd scripts/core/Fleet.gd fixtures/settlements.json fixtures/fleets.json scenes/views/WorldMap.gd scenes/ui/InspectSheet.gd scenes/ui/InspectSheet.tscn scenes/ui/FleetCard.gd tools/smoke_probe.gd docs/superpowers/specs/2026-09-07-islanders-client-skeleton-design.md test/core/settlement_test.gd test/core/fleet_test.gd test/scenes/inspect_sheet_test.gd test/scenes/fleet_card_test.gd test/scenes/world_map_test.gd
git commit -m "Show owners by nickname instead of account id"
```

---

### Task 11: Dokumentacja i przegląd wizualny

**Files:**
- Modify: `docs/superpowers/specs/2026-09-08-islanders-ui-v2-design.md`, `docs/superpowers/specs/2026-09-09-islanders-ui-v2-polish-design.md` (status)
- Poza gałęzią: `docs/architecture/data-flow.html` (patrz Step 3)

Ten task nie zmienia kodu. Stroi się tylko dokumenty, a strojenie `DENSITY` i `ZOOM_MIN` po obejrzeniu zrzutów zostaje decyzją człowieka, osobnym commitem po tym planie.

- [ ] **Step 1: Spec UI v2**

W `docs/superpowers/specs/2026-09-08-islanders-ui-v2-design.md`, przy każdej zmianie dopisz na końcu sekcji zdanie „Zmienione przez `2026-09-09-islanders-ui-v2-polish-design.md`.”:

| Sekcja | Zmiana |
|---|---|
| 2, tabela decyzji | „Ikony”: bez „zero zewnętrznych grafik” (zasada zniesiona; ikony zostają glifami do osobnej decyzji). „Zasoby w HUD”: pięć kart bez placeholdera złota. Nowy wiersz „Gęstość”: `gap()` z `DENSITY` obok `px()`. |
| 3.4 | Drzewo `UI` ze `StatusRow` (`PopPanel`: ikona `people`, `PopBar`, `PopLabel`; potem `HintPanel`); populacja z ostrzeżeniem `BLOOD` od 95 % limitu, bez ostrzeżenia przy limicie 0. |
| 3.5 | `BackPlaque`: sam `Icon "back"` w kwadracie `px(46)`, `tooltip_text` „Wróć do osady”. `ZOOM_MIN = 0.15`. Wyspy, pierścienie, etykiety i trafianie liczone od `WorldGrid.island_center`. Tapnięcie zawsze `GameState.inspect(cell)` i `Sheets.open_inspect(cell)`, także dla własnej osady. |
| 4.2 | Obok `SCALE`: `DENSITY = 0.7` i `gap()`; tabela „przez `gap()` / przy `px()`” ze specu korekt, sekcja 4. |
| 4.3 | `stone`: bryła z jedną wewnętrzną krawędzią. Nowe `@export var knockout` z domyślnym `PARCHMENT`; `into_button` z wycięciem `OAK`; nagłówki `OAK`, chipy `OAK_DEEP`, karty zasobów kolor twarzy karty. |
| 5 | Drzewo paska ze specu korekt, 3.1; budżet wysokości ~14 %; karta nieprodukowana: `VELLUM`, `INK_SOFT`, puste tempo, bez `modulate`; orientacja pozioma przenosi karty do `IdentityRow`. Usuń opis `GoldPanel`, `Avatar` i `PopulationRow`. |
| 6.4 | `ModalBody` → `Body`; marginesy i separacje przez `gap()`. |
| 7 | Tryb własnej osady: podpis „(x, y) · twoja osada”, `ActionButton` (`Primary`) „PRZEJDŹ DO OSADY” / „WRÓĆ DO OSADY”, sygnał `enter_settlement_requested(coord)` obsłużony w `Sheets`. Podpis cudzej osady z pseudonimem. „Widoczne jest dokładnie jedno z trzech dzieci” dotyczy trybów cudzej i niczyjej wyspy. |

- [ ] **Step 2: Status specu korekt**

W nagłówku `docs/superpowers/specs/2026-09-09-islanders-ui-v2-polish-design.md` zmień linię `Status:` na „Status: wdrożony na gałęzi `feat/ui-polish`; strojenie `DENSITY` i `ZOOM_MIN` po przeglądzie wizualnym”.

- [ ] **Step 3: Dokument architektury — poza gałęzią**

`docs/architecture/data-flow.html` jest w głównym katalogu nieśledzony, więc worktree go nie ma. Nie twórz go w worktree. W raporcie z tego taska wypisz dla kontrolera, co ta fala w nim dezaktualizuje:
- `HUD`: brak `Avatar`, `GoldPanel`, `PopulationRow`; `IdentityRow`.
- `IslandDetail`: `StatusRow` z populacją.
- `InspectSheet`: sygnał `enter_settlement_requested` → `Sheets._on_enter_settlement_requested` → `GameState.set_active_settlement` + `SceneManager.show_island_detail`; `WorldMap._on_tapped` nie woła już `set_active_settlement`.
- `GameState.world_seed()`; `Fleet.position_at(now, world_seed)`; `WorldGrid.island_center` / `island_offset_xy`.
- JSON: `ownerName` w osadzie i flocie; `offsetX`, `offsetY`, `offsetRange` w artefakcie kontraktu.

Kontroler aktualizuje dokument po scaleniu, w głównym katalogu, skillem `updating-architecture-doc`.

- [ ] **Step 4: Przegląd wizualny sondą**

```bash
./run_tests.sh
./run_smoke.sh
mkdir -p /tmp/ui-polish-final
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 1080x1920 res://tools/Capture.tscn -- /tmp/ui-polish-final 2>&1 | grep -E 'MEASURE|LABEL|ZA WĄSKA|CAPTURE|SCRIPT ERROR'
ls /tmp/ui-polish-final
```

Oczekiwane: testy i smoke zielone; wysokość paska w okolicy 14 % i nie więcej niż 16 %; żadna etykieta `ZA WĄSKA`. Obejrzyj `01-osada.png`, `02-arkusz-budynku.png`, `03-mapa.png`, `pasek*.png` i `status-osady*.png`. W raporcie podaj procent paska, liczbę testów i ścieżki do zrzutów, żeby człowiek mógł ocenić gęstość i przybliżenie.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-09-08-islanders-ui-v2-design.md docs/superpowers/specs/2026-09-09-islanders-ui-v2-polish-design.md
git commit -m "Bring the UI v2 spec in line with the polish wave"
```

---

## Po planie (nie dla wykonawcy tasków)

- Przegląd wizualny przez człowieka na zrzutach z Task 11 i na urządzeniu; ewentualne strojenie `DENSITY` i `ZOOM_MIN` osobnym commitem.
- Aktualizacja `docs/architecture/data-flow.html` skillem `updating-architecture-doc` w głównym katalogu (Task 11, Step 3).
- Przekazanie stronie API (`../IslandersAPI`): implementacja punktu 8 załącznika ADR 0001 i czasu podróży między położeniami (ADR 0003); test parytetu backendu musi przyjąć nowe pola `offsetX`, `offsetY`, `offsetRange` w `contract/world-parity.json`; publiczny widok osady nadal wysyła `ownerId`, co jest wyciekiem identyfikatora konta w świetle glosariusza.
