# Islanders UI v2 „Chart & Timber” – plan implementacji

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nadać klientowi Godot szatę „Chart & Timber” (motyw w kodzie, ikony rysowane kodem) i zmienić nawigację na: osada aktywna jako dom, mapa jako narzędzie, floty / inspekcja / budynek jako arkusze od dołu.

**Architecture:** `Main.tscn` trzyma morze, stałe warstwy chrome (`HUD`, `Dock`, `Sheets`) i `ViewContainer`, w którym `SceneManager` podmienia dwa widoki: `IslandDetail` (osada aktywna) i `WorldMap`. Motyw budowany przez `MedievalTheme.build()` i wgrywany globalnie do `ThemeDB`. Widoki wołają chrome przez grupy węzłów `hud` i `sheets`; dane wyłącznie z autoloadu `GameState`.

**Tech Stack:** Godot 4.8 dev4 (GL Compatibility), GDScript 2.0, gdUnit4 (`./run_tests.sh`), smoke test scen (`./run_smoke.sh`), fonty Cinzel i Spectral (OFL).

**Spec:** `docs/superpowers/specs/2026-09-08-islanders-ui-v2-design.md`

## Global Constraints

- Praca w osobnym worktree `.worktree/ui-v2` na gałęzi `feat/ui-v2` od `feat/client-skeleton` (Task 0). Wszystkie komendy poniżej uruchamiane z katalogu worktree.
- Godot: `/Applications/Godot.app/Contents/MacOS/Godot` (zmienna `GODOT` w skryptach). Viewport 1080 × 1920, `canvas_items`, `aspect = expand`.
- Terminologia z `CONTEXT.md` (osada, wyspa, flota, znalezisko, slot). Teksty UI po polsku. Komentarze w kodzie po polsku, identyfikatory po angielsku.
- Zero zewnętrznych grafik i emoji. Jedyne assety binarne: trzy pliki TTF w `ui/fonts/` z licencjami OFL.
- Skala projektu: `MedievalTheme.SCALE = 2.77`; każdy wymiar z mocka (dla 390 px) przechodzi przez `MedievalTheme.px()`.
- `scripts/core/` nie zależy od żadnego autoloadu ani węzła.
- Każde zadanie kończy się zielonym `./run_tests.sh` dla wskazanych plików i (od Task 4) zielonym `./run_smoke.sh`.
- Commity po polsku lub angielsku, jak w historii repo; treść zwięzła, z opisem „dlaczego”.

## Odstępstwa od specu (uzasadnione w trakcie planowania)

1. **Motyw wgrywany globalnie**, nie przypisany do `theme` korzenia: `CanvasLayer` i `Node2D` przerywają dziedziczenie motywu w Godot 4, więc `MedievalTheme.install()` robi `ThemeDB.get_default_theme().merge_with(build())`. Efekt ten sam, bez ręcznego przypinania motywu do każdej warstwy.
2. **Cinzel to font zmienny** (`Cinzel[wght].ttf`, brak pliku statycznego Bold w repozytorium Google Fonts). Zapisany jako `ui/fonts/Cinzel-Variable.ttf`, pogrubienie przez `FontVariation` z `{"wght": 700}`.
3. **`emulate_mouse_from_touch = true`** w `project.godot`. Wbudowany `Button` reaguje wyłącznie na zdarzenia myszy; bez emulacji przyciski nie działałyby na telefonie. Kamera mapy ignoruje zdarzenia myszy poza kółkiem, więc nic się nie dubluje.
4. **`FleetCard.refresh(fleet, now, player_id)`** przyjmuje id gracza jawnie, żeby karta była testowalna bez `GameState`.
5. **Widoki znajdują chrome przez grupy** `hud` i `sheets` (`get_tree().get_first_node_in_group`), a `Main` pozostaje `Node`, nie `Control`.

---

## Mapa plików

| Plik | Odpowiedzialność |
|---|---|
| `ui/fonts/*.ttf`, `ui/fonts/OFL-*.txt` | fonty i licencje |
| `scenes/ui/MedievalTheme.gd` | paleta, `flat()`, `plaque()`, `px()`, `build()`, `install()` |
| `scenes/ui/Icon.gd` | `Control` rysujący glify z `_draw()`; `into_button()` |
| `scenes/ui/SafeArea.gd` | offsety safe area w pikselach canvasu |
| `scenes/ui/HUD.tscn/.gd` | górny pasek osady aktywnej |
| `scenes/ui/Dock.tscn/.gd` | przyciski „Floty” (z odznaką) i „Mapa” |
| `scenes/ui/Sheets.tscn/.gd` | backdrop + zarządca trzech arkuszy |
| `scenes/ui/SheetStyle.gd` | wspólne style arkuszy (margines, uchwyt) |
| `scenes/ui/BuildingSheet.tscn/.gd` | arkusz budynku |
| `scenes/ui/InspectSheet.tscn/.gd` | arkusz cudzej / niczyjej wyspy |
| `scenes/ui/FleetsSheet.tscn/.gd`, `FleetCard.tscn/.gd` | lista flot |
| `scenes/procedural/SlotPlaque.gd` | plakietka slotu (Node2D) |
| `scenes/procedural/IslandGenerator.gd` | sloty jako `SlotPlaque`, `set_pressed`, `clear` |
| `scenes/views/Main.tscn/.gd` | morze, motyw, chrome, start w osadzie |
| `scenes/views/IslandDetail.tscn/.gd` | dom: osada aktywna, dotyk slotów |
| `scenes/views/WorldMap.tscn/.gd`, `MapCamera.gd`, `Water.gd` | mapa z warstwą UI, pamięć kamery, `focus`, `zoom_by` |
| `scenes/autoload/SceneManager.gd` | `map_camera_state`, `show_world_map_at`, fade |
| `scripts/core/TimeUtil.gd`, `Fleet.gd`, `Buildings.gd`, `ResourceTypes.gd` | `format_thousands`, `MISSION_*`, `ICONS`, `DESCRIPTIONS` |
| `tools/smoke_probe.gd` | smoke test nowego przepływu |

---

### Task 0: Worktree i stan wyjściowy

**Files:**
- Create: `.worktree/ui-v2/` (worktree git)

- [ ] **Step 1: Utwórz worktree**

```bash
cd /Users/sdawidziak/_TweetGeek/_Godot/Islanders/islanders
git worktree add .worktree/ui-v2 -b feat/ui-v2 feat/client-skeleton
cd .worktree/ui-v2
git log --oneline -1
```

Oczekiwane: ostatni commit to `Add UI v2 "Chart & Timber" design spec` (lub nowszy na `feat/client-skeleton`). Od tej chwili każda komenda działa w `.worktree/ui-v2`.

- [ ] **Step 2: Zaimportuj projekt i uruchom testy bazowe**

```bash
./run_tests.sh
./run_smoke.sh
```

Oczekiwane: gdUnit raportuje 0 błędów, smoke kończy się `SMOKE PASSED` i kodem 0. Jeśli coś jest czerwone na starcie, zatrzymaj się i zgłoś to użytkownikowi zamiast naprawiać po drodze.

---

### Task 1: Fonty i `MedievalTheme`

**Files:**
- Create: `ui/fonts/Cinzel-Variable.ttf`, `ui/fonts/Spectral-Regular.ttf`, `ui/fonts/Spectral-SemiBold.ttf`, `ui/fonts/OFL-Cinzel.txt`, `ui/fonts/OFL-Spectral.txt`
- Create: `scenes/ui/MedievalTheme.gd`
- Test: `test/scenes/medieval_theme_test.gd`

**Interfaces:**
- Produces: `class_name MedievalTheme` ze stałymi kolorów (`PARCHMENT`, `VELLUM`, `CHART`, `RULE`, `OAK`, `OAK_DEEP`, `OAK_EDGE`, `BRASS`, `BRASS_HOT`, `INK`, `INK_SOFT`, `CREAM`, `CREAM_SOFT`, `SEA`, `BLOOD`, `MOSS`, `SECTION`, `RATE`, `RAID`, `SHORT_BG`), `SCALE`, `VARIATIONS: Dictionary`, `static func px(v: float) -> int`, `flat(bg, border, radius, border_width = 1, pad_h = 10, pad_v = 8) -> StyleBoxFlat`, `plaque(face = PARCHMENT) -> StyleBoxFlat`, `display_font() -> Font`, `build() -> Theme`, `install() -> void`.

- [ ] **Step 1: Pobierz fonty i licencje**

```bash
mkdir -p ui/fonts
curl -sSL -o ui/fonts/Cinzel-Variable.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf"
curl -sSL -o ui/fonts/Spectral-Regular.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/spectral/Spectral-Regular.ttf"
curl -sSL -o ui/fonts/Spectral-SemiBold.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/spectral/Spectral-SemiBold.ttf"
curl -sSL -o ui/fonts/OFL-Cinzel.txt "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/OFL.txt"
curl -sSL -o ui/fonts/OFL-Spectral.txt "https://raw.githubusercontent.com/google/fonts/main/ofl/spectral/OFL.txt"
ls -la ui/fonts && file ui/fonts/*.ttf
```

Oczekiwane: trzy pliki `TrueType Font data`, każdy powyżej 100 KB; dwa pliki tekstowe z nagłówkiem „SIL Open Font License”.

- [ ] **Step 2: Zaimportuj fonty do Godota**

```bash
"${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless --path . --import >/dev/null 2>&1; ls ui/fonts
```

Oczekiwane: obok każdego `.ttf` pojawia się `.ttf.import`. Pliki `.import` i `.uid` są śledzone w git (jak reszta sidecarów w repo).

- [ ] **Step 3: Napisz test motywu**

`test/scenes/medieval_theme_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_px_scales_and_rounds() -> void:
	assert_int(MedievalTheme.px(10.0)).is_equal(28)
	assert_int(MedievalTheme.px(0.0)).is_equal(0)
	assert_float(MedievalTheme.SCALE).is_greater(0.0)


func test_build_has_every_variation() -> void:
	var t := MedievalTheme.build()
	assert_object(t).is_not_null()
	assert_object(t.default_font).is_not_null()
	for name: StringName in MedievalTheme.VARIATIONS:
		assert_str(String(t.get_type_variation_base(name))) \
			.override_failure_message("brak wariacji %s" % name) \
			.is_equal(String(MedievalTheme.VARIATIONS[name]))


func test_flat_scales_paddings() -> void:
	var sb := MedievalTheme.flat(Color.RED, Color.BLUE, 4, 1, 10, 8)
	assert_int(int(sb.content_margin_left)).is_equal(MedievalTheme.px(10))
	assert_int(int(sb.content_margin_top)).is_equal(MedievalTheme.px(8))
	assert_int(sb.corner_radius_top_left).is_equal(MedievalTheme.px(4))
	assert_int(sb.border_width_left).is_equal(MedievalTheme.px(1))


func test_plaque_has_hard_shadow() -> void:
	var sb := MedievalTheme.plaque()
	assert_that(sb.shadow_color).is_equal(MedievalTheme.OAK_DEEP)
	assert_int(sb.shadow_size).is_equal(MedievalTheme.px(3))


func test_install_reaches_plain_label() -> void:
	MedievalTheme.install()
	var label: Label = auto_free(Label.new())
	add_child(label)
	assert_that(label.get_theme_color("font_color")).is_equal(MedievalTheme.INK)
	label.theme_type_variation = &"Title"
	assert_that(label.get_theme_color("font_color")).is_equal(MedievalTheme.CREAM)
```

- [ ] **Step 4: Uruchom test, oczekuj błędu parsowania**

```bash
./run_tests.sh test/scenes/medieval_theme_test.gd
```

Oczekiwane: błąd `Identifier "MedievalTheme" not declared` (klasa nie istnieje).

- [ ] **Step 5: Napisz `scenes/ui/MedievalTheme.gd`**

```gdscript
class_name MedievalTheme
extends RefCounted

## Motyw „Chart & Timber”: dębowy chrome, mosiężne linie, pergaminowe karty.
## Morze (tło Main) jest jedyną ciemną powierzchnią; UI leży na nim jak drewno i papier.
## Wymiary z projektu (viewport 390 px) przechodzą przez px(), bo nasz viewport ma 1080 px.

const SCALE := 2.77

const PARCHMENT := Color("eadfc4")
const VELLUM := Color("dccca6")
const CHART := Color("e3d3ac")
const RULE := Color("cbb484")
const OAK := Color("5a3e27")
const OAK_DEEP := Color("3d2917")
const OAK_EDGE := Color("8a6a3e")
const BRASS := Color("b8862b")
const BRASS_HOT := Color("dfae44")
const INK := Color("2a2015")
const INK_SOFT := Color("5c4b36")
const CREAM := Color("f3ead4")
const CREAM_SOFT := Color("d6c39d")
const SEA := Color("17383d")
const BLOOD := Color("8c2f2a")
const MOSS := Color("5f7c3f")
const SECTION := Color("7a4a18")
const RATE := Color("3f6033")
const RAID := Color("9e3b32")
const SHORT_BG := Color("e7c9c4")

const FONT_DISPLAY := preload("res://ui/fonts/Cinzel-Variable.ttf")
const FONT_BODY := preload("res://ui/fonts/Spectral-Regular.ttf")
const FONT_BODY_SEMI := preload("res://ui/fonts/Spectral-SemiBold.ttf")

## wariacja -> typ bazowy; test sprawdza, że build() tworzy każdą z nich
const VARIATIONS := {
	&"Title": &"Label",
	&"Caption": &"Label",
	&"SectionHeader": &"Label",
	&"Amount": &"Label",
	&"Rate": &"Label",
	&"Badge": &"Label",
	&"BarPanel": &"PanelContainer",
	&"ResCard": &"PanelContainer",
	&"Chip": &"PanelContainer",
	&"Plaque": &"PanelContainer",
	&"Sheet": &"PanelContainer",
	&"ModalHeader": &"PanelContainer",
	&"FleetCard": &"PanelContainer",
	&"Primary": &"Button",
	&"Danger": &"Button",
	&"ToolButton": &"Button",
	&"RaidBar": &"ProgressBar",
	&"ScoutBar": &"ProgressBar",
}

static var _display: FontVariation = null
static var _installed := false


static func px(v: float) -> int:
	return int(roundf(v * SCALE))


static func flat(bg: Color, border: Color, radius: int, border_width: int = 1,
		pad_h: int = 10, pad_v: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(px(radius))
	sb.border_color = border
	sb.set_border_width_all(px(border_width))
	sb.content_margin_left = px(pad_h)
	sb.content_margin_right = px(pad_h)
	sb.content_margin_top = px(pad_v)
	sb.content_margin_bottom = px(pad_v)
	sb.anti_aliasing = true
	return sb


## Rzeźbiona plakietka: pergaminowa twarz, dębowa krawędź, twardy cień pod spodem.
static func plaque(face: Color = PARCHMENT) -> StyleBoxFlat:
	var sb := flat(face, OAK, 5, 2, 8, 8)
	sb.shadow_color = OAK_DEEP
	sb.shadow_size = px(3)
	sb.shadow_offset = Vector2(0, px(3))
	return sb


## Cinzel jest fontem zmiennym; pogrubienie przez oś wght.
static func display_font() -> Font:
	if _display == null:
		_display = FontVariation.new()
		_display.base_font = FONT_DISPLAY
		_display.variation_opentype = {"wght": 700}
	return _display


static func _variation(t: Theme, name: StringName, base: StringName) -> void:
	t.set_type_variation(name, base)


static func build() -> Theme:
	var t := Theme.new()
	var display := display_font()
	var body: Font = FONT_BODY
	var body_semi: Font = FONT_BODY_SEMI
	t.default_font = body
	t.default_font_size = px(15)

	# --- Label ---------------------------------------------------------------
	t.set_font("font", "Label", body)
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", px(15))
	_variation(t, &"Title", &"Label")
	t.set_font("font", "Title", display)
	t.set_color("font_color", "Title", CREAM)
	t.set_font_size("font_size", "Title", px(17))
	_variation(t, &"Caption", &"Label")
	t.set_color("font_color", "Caption", CREAM_SOFT)
	t.set_font_size("font_size", "Caption", px(12))
	_variation(t, &"SectionHeader", &"Label")
	t.set_font("font", "SectionHeader", display)
	t.set_color("font_color", "SectionHeader", SECTION)
	t.set_font_size("font_size", "SectionHeader", px(11))
	_variation(t, &"Amount", &"Label")
	t.set_font("font", "Amount", body_semi)
	t.set_color("font_color", "Amount", INK)
	t.set_font_size("font_size", "Amount", px(14))
	_variation(t, &"Rate", &"Label")
	t.set_color("font_color", "Rate", RATE)
	t.set_font_size("font_size", "Rate", px(11))
	_variation(t, &"Badge", &"Label")
	t.set_font("font", "Badge", display)
	t.set_color("font_color", "Badge", INK)
	t.set_font_size("font_size", "Badge", px(10))
	t.set_stylebox("normal", "Badge", flat(BRASS, BRASS, 2, 0, 5, 3))

	# --- Panele --------------------------------------------------------------
	t.set_stylebox("panel", "PanelContainer", flat(PARCHMENT, OAK_EDGE, 3))
	_variation(t, &"BarPanel", &"PanelContainer")
	var bar := flat(OAK, BRASS, 0, 0, 0, 0)
	bar.border_width_bottom = px(2)
	t.set_stylebox("panel", "BarPanel", bar)
	_variation(t, &"ResCard", &"PanelContainer")
	t.set_stylebox("panel", "ResCard", flat(PARCHMENT, OAK_DEEP, 4, 1, 8, 6))
	_variation(t, &"Chip", &"PanelContainer")
	t.set_stylebox("panel", "Chip", flat(OAK_DEEP, BRASS, 4, 1, 8, 5))
	_variation(t, &"Plaque", &"PanelContainer")
	t.set_stylebox("panel", "Plaque", plaque())
	_variation(t, &"Sheet", &"PanelContainer")
	var sheet := flat(PARCHMENT, BRASS, 0, 0, 14, 14)
	sheet.border_width_top = px(3)
	sheet.shadow_color = Color(0.08, 0.04, 0.0, 0.45)
	sheet.shadow_size = px(16)
	t.set_stylebox("panel", "Sheet", sheet)
	_variation(t, &"ModalHeader", &"PanelContainer")
	t.set_stylebox("panel", "ModalHeader", flat(OAK, OAK, 0, 0, 14, 9))
	_variation(t, &"FleetCard", &"PanelContainer")
	var fleet := flat(PARCHMENT, OAK_EDGE, 3, 1, 11, 10)
	fleet.border_width_left = px(5)
	t.set_stylebox("panel", "FleetCard", fleet)

	# --- Przyciski -----------------------------------------------------------
	t.set_font("font", "Button", display)
	t.set_font_size("font_size", "Button", px(13))
	t.set_color("font_color", "Button", INK_SOFT)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("9a8a70"))
	t.set_stylebox("normal", "Button", flat(Color(0, 0, 0, 0), OAK_EDGE, 4, 1, 14, 14))
	t.set_stylebox("hover", "Button", flat(VELLUM, OAK, 4, 1, 14, 14))
	t.set_stylebox("pressed", "Button", flat(VELLUM, OAK, 4, 1, 14, 14))
	t.set_stylebox("disabled", "Button", flat(Color(0, 0, 0, 0), Color("9a8a70"), 4, 1, 14, 14))
	_variation(t, &"Primary", &"Button")
	t.set_color("font_color", "Primary", INK)
	t.set_color("font_hover_color", "Primary", INK)
	t.set_color("font_pressed_color", "Primary", INK)
	var prim := flat(BRASS, SECTION, 4, 2, 14, 14)
	prim.shadow_color = SECTION
	prim.shadow_size = px(3)
	prim.shadow_offset = Vector2(0, px(3))
	t.set_stylebox("normal", "Primary", prim)
	t.set_stylebox("hover", "Primary", flat(BRASS_HOT, SECTION, 4, 2, 14, 14))
	var prim_down := flat(BRASS_HOT, SECTION, 4, 2, 14, 14)
	prim_down.content_margin_top = px(17)   # 3 px skoku w dół, cień znika
	prim_down.content_margin_bottom = px(11)
	t.set_stylebox("pressed", "Primary", prim_down)
	_variation(t, &"Danger", &"Button")
	t.set_color("font_color", "Danger", BLOOD)
	t.set_color("font_hover_color", "Danger", BLOOD)
	t.set_color("font_pressed_color", "Danger", BLOOD)
	t.set_stylebox("normal", "Danger", flat(Color(0, 0, 0, 0), BLOOD, 4, 2, 14, 14))
	t.set_stylebox("hover", "Danger", flat(SHORT_BG, BLOOD, 4, 2, 14, 14))
	t.set_stylebox("pressed", "Danger", flat(SHORT_BG, BLOOD, 4, 2, 14, 14))
	_variation(t, &"ToolButton", &"Button")      # 46 px dębowe przyciski docku i mapy
	t.set_color("font_color", "ToolButton", CREAM)
	t.set_color("font_hover_color", "ToolButton", CREAM)
	t.set_color("font_pressed_color", "ToolButton", CREAM)
	t.set_font_size("font_size", "ToolButton", px(10))
	t.set_stylebox("normal", "ToolButton", flat(OAK, BRASS, 5, 2, 0, 0))
	t.set_stylebox("hover", "ToolButton", flat(OAK_DEEP, BRASS_HOT, 5, 2, 0, 0))
	t.set_stylebox("pressed", "ToolButton", flat(OAK_DEEP, BRASS_HOT, 5, 2, 0, 0))

	# --- ProgressBar ---------------------------------------------------------
	t.set_stylebox("background", "ProgressBar", flat(RULE, OAK_EDGE, 2, 1, 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(BRASS, BRASS, 2, 0, 0, 0))
	t.set_color("font_color", "ProgressBar", INK_SOFT)
	_variation(t, &"RaidBar", &"ProgressBar")
	t.set_stylebox("fill", "RaidBar", flat(RAID, RAID, 2, 0, 0, 0))
	_variation(t, &"ScoutBar", &"ProgressBar")
	t.set_stylebox("fill", "ScoutBar", flat(RATE, RATE, 2, 0, 0, 0))

	# --- Reszta --------------------------------------------------------------
	t.set_font("font", "LineEdit", body)
	t.set_stylebox("normal", "LineEdit", flat(PARCHMENT, OAK_DEEP, 3, 1, 10, 10))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color("7a6a50"))
	t.set_color("caret_color", "LineEdit", SECTION)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("separator", "HSeparator", flat(OAK_EDGE, OAK_EDGE, 0, 0, 0, 0))
	t.set_constant("separation", "HSeparator", 1)
	t.set_constant("separation", "VBoxContainer", px(9))
	t.set_constant("separation", "HBoxContainer", px(6))
	return t


## CanvasLayer i Node2D przerywają dziedziczenie motywu, więc zamiast przypinać go do korzenia
## scalamy go z domyślnym motywem silnika: dotyczy wtedy każdej kontrolki w grze.
static func install() -> void:
	if _installed:
		return
	_installed = true
	ThemeDB.get_default_theme().merge_with(build())
	ThemeDB.fallback_font = FONT_BODY
	ThemeDB.fallback_font_size = px(15)
```

- [ ] **Step 6: Uruchom test, oczekuj zielonego**

```bash
./run_tests.sh test/scenes/medieval_theme_test.gd
```

Oczekiwane: 5 testów, 0 błędów. Jeśli `test_install_reaches_plain_label` pada na wariacji `Title`, sprawdź, czy `Theme.merge_with` w tej wersji Godota kopiuje wariacje typów; w razie potrzeby w `install()` dodaj pętlę `for v in VARIATIONS: ThemeDB.get_default_theme().set_type_variation(v, VARIATIONS[v])`.

- [ ] **Step 7: Commit**

```bash
git add ui/fonts scenes/ui/MedievalTheme.gd scenes/ui/MedievalTheme.gd.uid test/scenes/medieval_theme_test.gd test/scenes/medieval_theme_test.gd.uid
git commit -m "Add Chart & Timber theme built in code with Cinzel and Spectral fonts"
```

---

### Task 2: `Icon` i stałe ikon oraz opisów

**Files:**
- Create: `scenes/ui/Icon.gd`
- Modify: `scripts/core/ResourceTypes.gd` (dodaj `ICONS`), `scripts/core/Buildings.gd` (dodaj `ICONS`, `DESCRIPTIONS`, `icon()`)
- Test: `test/scenes/icon_test.gd`, `test/core/buildings_test.gd`

**Interfaces:**
- Consumes: `MedievalTheme.INK`, `MedievalTheme.PARCHMENT`.
- Produces: `class_name Icon extends Control` z `@export var kind: StringName`, `@export var color: Color`, `const KINDS: Array[StringName]`, `static func is_known(kind) -> bool`, `static func into_button(button: Button, kind: StringName, color: Color, inset: float) -> Icon`. `ResourceTypes.ICONS: Dictionary` (klucz zasobu → `StringName`). `Buildings.ICONS`, `Buildings.DESCRIPTIONS`, `static func icon(t: Type) -> StringName`.

- [ ] **Step 1: Testy**

`test/core/buildings_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_every_building_has_icon_and_description() -> void:
	for t in Buildings.Type.values():
		assert_bool(Buildings.DESCRIPTIONS.has(t)).override_failure_message("brak opisu %s" % Buildings.key(t)).is_true()
		assert_str(String(Buildings.icon(t))).is_not_empty()


func test_extraction_buildings_use_resource_icon() -> void:
	assert_str(String(Buildings.icon(Buildings.Type.SAWMILL))).is_equal("wood")
	assert_str(String(Buildings.icon(Buildings.Type.SULFUR_PIT))).is_equal("sulfur")
	assert_str(String(Buildings.icon(Buildings.Type.TOWN_HALL))).is_equal("town_hall")


func test_every_resource_has_icon() -> void:
	for r in ResourceTypes.ALL:
		assert_bool(ResourceTypes.ICONS.has(r)).is_true()
```

`test/scenes/icon_test.gd`:

```gdscript
extends GdUnitTestSuite

const SPEC_KINDS: Array[StringName] = [
	&"wood", &"stone", &"food", &"iron", &"sulfur",
	&"town_hall", &"barracks", &"shipyard", &"warehouse",
	&"anchor", &"map", &"fleet", &"people", &"gold",
	&"plus", &"minus", &"close", &"back",
	&"raid", &"trade", &"scout", &"colonize", &"return",
]


func test_spec_kinds_are_known() -> void:
	for k in SPEC_KINDS:
		assert_bool(Icon.is_known(k)).override_failure_message("nieznany kind %s" % k).is_true()
	assert_bool(Icon.is_known(&"nope")).is_false()


func test_icons_and_resource_icons_are_known() -> void:
	for r in ResourceTypes.ALL:
		assert_bool(Icon.is_known(ResourceTypes.ICONS[r])).is_true()
	for t in Buildings.Type.values():
		assert_bool(Icon.is_known(Buildings.icon(t))).is_true()


func test_every_kind_draws_one_frame() -> void:
	var root: Control = auto_free(Control.new())
	add_child(root)
	for k in Icon.KINDS:
		var icon := Icon.new()
		icon.kind = k
		icon.custom_minimum_size = Vector2(48, 48)
		root.add_child(icon)
	await await_idle_frame()
	assert_int(root.get_child_count()).is_equal(Icon.KINDS.size())


func test_icon_ignores_mouse() -> void:
	var icon: Icon = auto_free(Icon.new())
	assert_int(icon.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_into_button_adds_full_rect_child() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	var icon := Icon.into_button(button, &"close", Color.BLACK, 6.0)
	assert_object(icon.get_parent()).is_same(button)
	assert_float(icon.anchor_right).is_equal(1.0)
	assert_float(icon.offset_left).is_equal(6.0)
	assert_float(icon.offset_right).is_equal(-6.0)
```

- [ ] **Step 2: Uruchom, oczekuj błędów**

```bash
./run_tests.sh test/core/buildings_test.gd
./run_tests.sh test/scenes/icon_test.gd
```

Oczekiwane: błędy parsowania (`ICONS`, `DESCRIPTIONS`, `Icon` nie istnieją).

- [ ] **Step 3: Dodaj stałe do `ResourceTypes.gd`** (po `LABELS`)

```gdscript
## Zasób -> Icon.kind
const ICONS := {
	"wood": &"wood",
	"stone": &"stone",
	"food": &"food",
	"iron": &"iron",
	"sulfur": &"sulfur",
}
```

- [ ] **Step 4: Dodaj stałe i `icon()` do `Buildings.gd`** (po `EXTRACTS`)

```gdscript
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
```

- [ ] **Step 5: Napisz `scenes/ui/Icon.gd`**

```gdscript
class_name Icon
extends Control

## Płaski glif rysowany w _draw() na siatce 24 × 24 skalowanej do size. Zero tekstur, zero emoji.
## Nieznany kind: kółko z obrysem i jedno push_warning na instancję.

const GRID := 24.0
const KINDS: Array[StringName] = [
	&"wood", &"stone", &"food", &"iron", &"sulfur",
	&"town_hall", &"barracks", &"shipyard", &"warehouse",
	&"anchor", &"map", &"fleet", &"people", &"gold",
	&"plus", &"minus", &"close", &"back",
	&"raid", &"trade", &"scout", &"colonize", &"return",
]

@export var kind: StringName = &"":
	set(v):
		kind = v
		_warned = false
		queue_redraw()
@export var color: Color = MedievalTheme.INK:
	set(v):
		color = v
		queue_redraw()

var _warned := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func is_known(k: StringName) -> bool:
	return KINDS.has(k)


## Dodaje ikonę jako dziecko przycisku, rozciągniętą na cały przycisk z marginesem inset (px).
static func into_button(button: Button, k: StringName, c: Color, inset: float) -> Icon:
	var icon := Icon.new()
	icon.name = "Icon"
	icon.kind = k
	icon.color = c
	button.add_child(icon)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y) / GRID
	if s <= 0.0:
		return
	# wyśrodkowanie, gdy kontrolka nie jest kwadratem
	draw_set_transform((size - Vector2.ONE * GRID * s) / 2.0, 0.0, Vector2(s, s))
	if not is_known(kind):
		if not _warned:
			_warned = true
			push_warning("Icon: nieznany kind '%s'" % kind)
		draw_arc(Vector2(12, 12), 9.0, 0.0, TAU, 32, color, 2.0, true)
		return
	call("_draw_" + String(kind))


func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y)


func _poly(points: Array) -> void:
	var packed := PackedVector2Array()
	for pt in points:
		packed.append(pt)
	draw_colored_polygon(packed, color)


func _line(a: Vector2, b: Vector2, width: float = 2.0) -> void:
	draw_line(a, b, color, width, true)


func _draw_wood() -> void:
	_line(_p(4, 17), _p(20, 7), 4.5)
	_line(_p(4, 10), _p(14, 4), 3.0)
	_line(_p(11, 20), _p(20, 14), 3.0)


func _draw_stone() -> void:
	var pts: Array = []
	for i in 6:
		pts.append(Vector2(12, 12) + Vector2.from_angle(float(i) / 6.0 * TAU) * 9.0)
	_poly(pts)


func _draw_food() -> void:
	_line(_p(12, 21), _p(12, 6), 2.0)
	draw_circle(_p(12, 5), 2.6, color)
	draw_circle(_p(8, 9), 2.4, color)
	draw_circle(_p(16, 9), 2.4, color)
	draw_circle(_p(9, 13.5), 2.2, color)
	draw_circle(_p(15, 13.5), 2.2, color)


func _draw_iron() -> void:
	_poly([_p(3, 18), _p(21, 18), _p(17.5, 9), _p(6.5, 9)])


func _draw_sulfur() -> void:
	_poly([_p(12, 3), _p(21.5, 20.5), _p(2.5, 20.5)])
	draw_circle(_p(12, 15.5), 2.4, MedievalTheme.PARCHMENT)


func _draw_town_hall() -> void:
	draw_rect(Rect2(_p(5, 12), _p(14, 9)), color)
	_poly([_p(3, 12.5), _p(12, 5), _p(21, 12.5)])
	draw_rect(Rect2(_p(15, 3), _p(4, 6)), color)
	draw_rect(Rect2(_p(10.5, 15), _p(3, 6)), MedievalTheme.PARCHMENT)


func _draw_barracks() -> void:
	_poly([_p(4, 4), _p(20, 4), _p(20, 12), _p(12, 21), _p(4, 12)])
	_line(_p(12, 7), _p(12, 17), 1.6)
	_line(_p(7, 9), _p(17, 9), 1.6)


func _draw_shipyard() -> void:
	_draw_anchor()


func _draw_anchor() -> void:
	draw_arc(_p(12, 5), 2.2, 0.0, TAU, 20, color, 1.8, true)
	_line(_p(12, 7.5), _p(12, 20), 2.4)
	_line(_p(7, 10), _p(17, 10), 2.0)
	draw_arc(_p(12, 13), 7.0, 0.3, PI - 0.3, 20, color, 2.4, true)


func _draw_warehouse() -> void:
	draw_rect(Rect2(_p(4, 9), _p(16, 12)), color)
	_poly([_p(3, 9), _p(12, 4), _p(21, 9)])
	_line(_p(4, 14.5), _p(20, 14.5), 1.4)
	draw_rect(Rect2(_p(10, 15.5), _p(4, 5.5)), MedievalTheme.PARCHMENT)


func _draw_map() -> void:
	_poly([_p(3, 5), _p(9, 3), _p(15, 5), _p(21, 3), _p(21, 19), _p(15, 21), _p(9, 19), _p(3, 21)])
	draw_line(_p(9, 3), _p(9, 19), MedievalTheme.PARCHMENT, 1.4, true)
	draw_line(_p(15, 5), _p(15, 21), MedievalTheme.PARCHMENT, 1.4, true)


func _draw_fleet() -> void:
	_line(_p(11, 3), _p(11, 16), 2.0)
	_poly([_p(12, 4), _p(20, 15), _p(12, 15)])
	_poly([_p(3, 17), _p(21, 17), _p(18, 21), _p(6, 21)])


func _draw_people() -> void:
	draw_circle(_p(8, 8), 3.2, color)
	draw_circle(_p(16.5, 8), 3.2, color)
	_poly([_p(3, 21), _p(3, 16), _p(6, 13), _p(10, 13), _p(13, 16), _p(13, 21)])
	_poly([_p(11.5, 21), _p(11.5, 16), _p(14.5, 13), _p(18.5, 13), _p(21.5, 16), _p(21.5, 21)])


func _draw_gold() -> void:
	draw_circle(_p(12, 12), 9.0, color)
	draw_arc(_p(12, 12), 5.0, 0.0, TAU, 32, MedievalTheme.PARCHMENT, 1.8, true)


func _draw_plus() -> void:
	_line(_p(12, 4), _p(12, 20), 3.0)
	_line(_p(4, 12), _p(20, 12), 3.0)


func _draw_minus() -> void:
	_line(_p(4, 12), _p(20, 12), 3.0)


func _draw_close() -> void:
	_line(_p(5, 5), _p(19, 19), 2.6)
	_line(_p(19, 5), _p(5, 19), 2.6)


func _draw_back() -> void:
	_line(_p(20, 12), _p(6, 12), 2.6)
	_line(_p(6, 12), _p(12, 6), 2.6)
	_line(_p(6, 12), _p(12, 18), 2.6)


func _draw_raid() -> void:
	_line(_p(4, 20), _p(19, 5), 2.6)
	_line(_p(20, 20), _p(5, 5), 2.6)
	_line(_p(4, 15), _p(9, 20), 2.0)
	_line(_p(20, 15), _p(15, 20), 2.0)


func _draw_trade() -> void:
	draw_rect(Rect2(_p(4, 9), _p(16, 11)), color)
	draw_arc(_p(12, 9), 4.0, PI, TAU, 16, color, 2.0, true)
	draw_line(_p(12, 9), _p(12, 20), MedievalTheme.PARCHMENT, 1.6, true)


func _draw_scout() -> void:
	_poly([_p(4, 16), _p(8, 20), _p(20, 8), _p(16, 4)])
	draw_circle(_p(5.5, 18.5), 2.6, color)
	_line(_p(14, 7), _p(17, 10), 1.2)


func _draw_colonize() -> void:
	_line(_p(6, 3), _p(6, 21), 2.2)
	_poly([_p(7, 4), _p(20, 8), _p(7, 12)])


func _draw_return() -> void:
	draw_arc(_p(12, 12), 7.0, -PI / 2.0, PI, 24, color, 2.4, true)
	_poly([_p(3, 12), _p(8, 8), _p(8, 16)])
```

Uwaga: `draw_set_transform` z trzema argumentami (pozycja, obrót, skala) skaluje wszystkie kolejne wywołania, więc grubości linii też są w jednostkach siatki.

- [ ] **Step 6: Uruchom testy**

```bash
./run_tests.sh test/core/buildings_test.gd
./run_tests.sh test/scenes/icon_test.gd
```

Oczekiwane: 8 testów zielonych, brak `SCRIPT ERROR` w wyjściu (błąd w którymkolwiek `_draw_*` pojawia się w logu jako błąd skryptu).

- [ ] **Step 7: Commit**

```bash
git add scenes/ui/Icon.gd scenes/ui/Icon.gd.uid scripts/core/ResourceTypes.gd scripts/core/Buildings.gd test/core/buildings_test.gd test/core/buildings_test.gd.uid test/scenes/icon_test.gd test/scenes/icon_test.gd.uid
git commit -m "Add code-drawn Icon control and icon/description tables"
```

---

### Task 3: `format_thousands` i etykiety misji

**Files:**
- Modify: `scripts/core/TimeUtil.gd`, `scripts/core/Fleet.gd`
- Test: `test/core/time_util_test.gd`, `test/core/fleet_test.gd`

**Interfaces:**
- Produces: `TimeUtil.format_thousands(value: float) -> String`, `TimeUtil.THIN_SPACE`, `TimeUtil.format_eta(seconds: float) -> String` (`mm:ss`, a od godziny `h:mm:ss`), `Fleet.MISSION_LABELS: Dictionary`, `Fleet.MISSION_ICONS: Dictionary`.

- [ ] **Step 1: Testy** (dopisz na końcu istniejących plików)

`test/core/time_util_test.gd`:

```gdscript
func test_format_thousands() -> void:
	var sp := TimeUtil.THIN_SPACE
	assert_str(TimeUtil.format_thousands(0.0)).is_equal("0")
	assert_str(TimeUtil.format_thousands(999.9)).is_equal("999")
	assert_str(TimeUtil.format_thousands(1000.0)).is_equal("1" + sp + "000")
	assert_str(TimeUtil.format_thousands(12480.0)).is_equal("12" + sp + "480")
	assert_str(TimeUtil.format_thousands(9999999.0)).is_equal("9" + sp + "999" + sp + "999")
	assert_str(TimeUtil.format_thousands(10000000.0)).is_equal("10.0M")
	assert_str(TimeUtil.format_thousands(-1500.0)).is_equal("-1" + sp + "500")


func test_format_eta() -> void:
	assert_str(TimeUtil.format_eta(0.0)).is_equal("00:00")
	assert_str(TimeUtil.format_eta(1781.0)).is_equal("29:41")
	assert_str(TimeUtil.format_eta(3600.0)).is_equal("1:00:00")
	assert_str(TimeUtil.format_eta(7325.0)).is_equal("2:02:05")
```

`test/core/fleet_test.gd`:

```gdscript
func test_mission_labels_and_icons_cover_every_mission() -> void:
	for m in Fleet.MISSIONS:
		assert_bool(Fleet.MISSION_LABELS.has(m)).override_failure_message("brak etykiety %s" % m).is_true()
		assert_bool(Fleet.MISSION_ICONS.has(m)).override_failure_message("brak ikony %s" % m).is_true()
	assert_str(Fleet.MISSION_LABELS["EXPEDITION"]).is_equal("Wyprawa")
	assert_str(String(Fleet.MISSION_ICONS["ATTACK"])).is_equal("raid")
```

- [ ] **Step 2: Uruchom, oczekuj błędów**

```bash
./run_tests.sh test/core/time_util_test.gd
./run_tests.sh test/core/fleet_test.gd
```

- [ ] **Step 3: Implementacja**

`scripts/core/TimeUtil.gd`, dopisz po `format_countdown`:

```gdscript
const THIN_SPACE := " "


## 12480 -> "12 480" (wąska spacja), od 10 000 000 -> "10.0M", ujemne z minusem.
static func format_thousands(value: float) -> String:
	var v := floorf(value)
	if absf(v) >= 10000000.0:
		return "%.1fM" % (v / 1000000.0)
	var digits := str(int(absf(v)))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = THIN_SPACE + out
	return ("-" if v < 0.0 else "") + out


## "mm:ss", a od godziny "h:mm:ss".
static func format_eta(seconds: float) -> String:
	var s := maxi(int(seconds), 0)
	if s < 3600:
		return format_countdown(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
```

`scripts/core/Fleet.gd`, po `MISSIONS`:

```gdscript
const MISSION_LABELS := {
	"COLONIZE": "Kolonizacja",
	"ATTACK": "Atak",
	"TRANSPORT": "Transport",
	"EXPEDITION": "Wyprawa",
	"RETURN": "Powrót",
}

const MISSION_ICONS := {
	"COLONIZE": &"colonize",
	"ATTACK": &"raid",
	"TRANSPORT": &"trade",
	"EXPEDITION": &"scout",
	"RETURN": &"return",
}
```

- [ ] **Step 4: Uruchom testy core**

```bash
./run_tests.sh test/core
```

Oczekiwane: wszystkie zielone.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/TimeUtil.gd scripts/core/Fleet.gd test/core/time_util_test.gd test/core/fleet_test.gd
git commit -m "Add thousands/eta formatting and mission labels for the fleet UI"
```

---

### Task 4: `SafeArea`, morze i motyw w `Main`, ustawienie dotyku

**Files:**
- Create: `scenes/ui/SafeArea.gd`
- Modify: `scenes/views/Main.tscn`, `scenes/views/Main.gd`, `scenes/views/WorldMap.tscn`, `scenes/views/IslandDetail.tscn`, `scenes/ui/HUD.gd:79-90`, `project.godot`
- Test: `test/scenes/safe_area_test.gd`, `./run_smoke.sh`

**Interfaces:**
- Produces: `SafeArea.top_inset(viewport: Viewport) -> float`, `SafeArea.bottom_inset(viewport: Viewport) -> float` (piksele canvasu).

- [ ] **Step 1: Test `SafeArea`**

`test/scenes/safe_area_test.gd`:

```gdscript
extends GdUnitTestSuite


## Pod headless safe area = całe okno, więc oba offsety są zerem; test pilnuje kontraktu
## (nieujemne, w pikselach canvasu) i tego, że funkcje w ogóle da się wołać bez sceny.
func test_insets_are_non_negative() -> void:
	assert_float(SafeArea.top_inset(get_viewport())).is_greater_equal(0.0)
	assert_float(SafeArea.bottom_inset(get_viewport())).is_greater_equal(0.0)


func test_scale_converts_window_pixels_to_canvas_pixels() -> void:
	var vis := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	assert_float(SafeArea.scale_for(get_viewport())).is_equal_approx(vis.y / maxf(win.y, 1.0), 0.0001)
```

- [ ] **Step 2: Uruchom, oczekuj błędu parsowania**

```bash
./run_tests.sh test/scenes/safe_area_test.gd
```

- [ ] **Step 3: Napisz `scenes/ui/SafeArea.gd`**

```gdscript
class_name SafeArea
extends RefCounted

## Safe area jest w pikselach okna, a kontrolki w pikselach canvasu (stretch canvas_items),
## więc offsety trzeba przeskalować. Jedno miejsce dla HUD, docku i widoków.


static func scale_for(viewport: Viewport) -> float:
	var win := DisplayServer.window_get_size()
	var vis := viewport.get_visible_rect().size
	return vis.y / maxf(float(win.y), 1.0)


static func top_inset(viewport: Viewport) -> float:
	var safe := DisplayServer.get_display_safe_area()
	return maxf(float(safe.position.y), 0.0) * scale_for(viewport)


static func bottom_inset(viewport: Viewport) -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	return maxf(float(win.y - safe.end.y), 0.0) * scale_for(viewport)
```

- [ ] **Step 4: Użyj `SafeArea` w HUD** (`scenes/ui/HUD.gd`, zastąp `_apply_safe_area`)

```gdscript
## Przesuwa pasek pod notch; pasek rośnie z zawartością, więc ustawiamy tylko górną krawędź.
func _apply_safe_area() -> void:
	top_bar.offset_top = SafeArea.top_inset(get_viewport())
	top_bar.offset_bottom = top_bar.offset_top + BAR_HEIGHT
```

(`BAR_HEIGHT` znika dopiero w Task 5.)

- [ ] **Step 5: Przepisz `scenes/views/Main.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/views/Main.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="2"]

[node name="Main" type="Node"]
script = ExtResource("1")

[node name="SeaBackground" type="CanvasLayer" parent="."]
layer = -100

[node name="Sea" type="ColorRect" parent="SeaBackground"]
anchors_preset = 15
mouse_filter = 2
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.0902, 0.2196, 0.2392, 1)

[node name="ViewContainer" type="Node" parent="."]

[node name="HUD" parent="." instance=ExtResource("2")]
```

`scenes/views/Main.gd`:

```gdscript
extends Node

@onready var view_container: Node = $ViewContainer
@onready var sea: ColorRect = $SeaBackground/Sea


func _ready() -> void:
	MedievalTheme.install()
	sea.color = MedievalTheme.SEA
	SceneManager.register_container(view_container)
	GameState.state_loaded.connect(SceneManager.show_world_map, CONNECT_ONE_SHOT)
	ApiClient.request_failed.connect(func(reason: String) -> void: push_error("Ładowanie nieudane: %s" % reason))
	ApiClient.load_initial()
```

- [ ] **Step 6: Usuń `Background` z obu widoków**

W `scenes/views/WorldMap.tscn` i `scenes/views/IslandDetail.tscn` usuń bloki `[node name="Background" type="CanvasLayer" ...]` oraz `[node name="Sea" type="ColorRect" parent="Background"]` (wraz z ich właściwościami). Nic w skryptach się do nich nie odwołuje.

- [ ] **Step 7: Włącz emulację myszy z dotyku** (`project.godot`, sekcja `[input_devices]`)

```
pointing/emulate_touch_from_mouse=true
pointing/emulate_mouse_from_touch=true
```

Powód: wbudowany `Button` obsługuje tylko zdarzenia myszy, więc bez tej emulacji przyciski nie reagują na dotyk na urządzeniu. Godot nie emuluje myszy z dotyku, który sam powstał z emulacji myszy, więc na desktopie nic się nie dubluje.

- [ ] **Step 8: Uruchom testy i smoke**

```bash
./run_tests.sh test/scenes/safe_area_test.gd
./run_tests.sh test/scenes
./run_smoke.sh
```

Oczekiwane: zielono, `SMOKE PASSED`. Smoke nie sprawdza jeszcze motywu; sprawdza za to, że przeciągnięcie po pasku HUD dalej rusza mapę.

- [ ] **Step 9: Commit**

```bash
git add scenes/ui/SafeArea.gd scenes/ui/SafeArea.gd.uid scenes/ui/HUD.gd scenes/views/Main.tscn scenes/views/Main.gd scenes/views/WorldMap.tscn scenes/views/IslandDetail.tscn project.godot test/scenes/safe_area_test.gd test/scenes/safe_area_test.gd.uid
git commit -m "Install the theme globally, move the sea to Main, add SafeArea helper"
```

---

### Task 5: Górny pasek HUD w nowej szacie

**Files:**
- Modify: `scenes/ui/HUD.tscn` (całość), `scenes/ui/HUD.gd` (całość), `tools/smoke_probe.gd:76-79,194-196`
- Test: `test/scenes/hud_test.gd`, `./run_smoke.sh`

**Interfaces:**
- Consumes: `Icon`, `MedievalTheme.px`, `SafeArea.top_inset`, `TimeUtil.format_thousands`, `ResourceTypes.ICONS`, `Settlement.produces`, `GameState.active_settlement_changed`, `settlement_updated`.
- Produces: HUD w grupie `hud`; pola `top_bar`, `settlement_name: Label`, `biome_badge: Label`, `subtitle: Label`, `gold_label: Label`, `pop_bar: ProgressBar`, `pop_label: Label`, `cards: Dictionary` (zasób → `PanelContainer`), `func icon_of(resource: String) -> Icon`, `func amount_of(resource: String) -> Label`, `func rate_of(resource: String) -> Label`, `func bar_height() -> float`.

- [ ] **Step 1: Test HUD**

`test/scenes/hud_test.gd`:

```gdscript
extends GdUnitTestSuite

const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
## (103, 100) to ląd TROPICAL dla ziarna 1337 (jak w world_map_test.gd).
const HOME := Vector2i(103, 100)


func before_test() -> void:
	GameState.reset()
	GameState.apply_world({
		"id": "w1", "seed": 1337, "size": {"w": 200, "h": 200},
		"playerId": 7, "homeSettlement": {"x": HOME.x, "y": HOME.y},
	})
	GameState.apply_settlements([{
		"x": HOME.x, "y": HOME.y, "ownerId": 7, "name": "Koralowa",
		"resources": {"wood": 12480, "food": 300},
		"productionPerHour": {"wood": 120, "food": 200},
		"capacity": 20000, "population": 118, "populationMax": 120,
		"lastSyncAt": TimeUtil.to_iso8601(TimeUtil.now()),
	}])
	GameState.set_active_settlement(HOME)


func after_test() -> void:
	GameState.reset()


func _hud() -> CanvasLayer:
	var hud: CanvasLayer = auto_free(HUD_SCENE.instantiate())
	add_child(hud)
	return hud


func test_profile_row_shows_active_settlement() -> void:
	var hud := _hud()
	assert_str(hud.settlement_name.text).is_equal("Koralowa")
	assert_str(hud.biome_badge.text).is_equal("TROPICAL")
	assert_str(hud.subtitle.text).is_equal("Świat w1 · (103, 100)")
	assert_str(hud.gold_label.text).is_equal("0")


func test_cards_show_amounts_and_rates() -> void:
	var hud := _hud()
	hud._process(0.0)
	assert_str(hud.amount_of("wood").text).is_equal("12" + TimeUtil.THIN_SPACE + "480")
	assert_str(hud.rate_of("wood").text).is_equal("+120/h")
	assert_str(hud.rate_of("stone").text).is_equal("")
	assert_float(hud.cards["stone"].modulate.a).is_equal(hud.DIMMED)
	assert_float(hud.cards["wood"].modulate.a).is_equal(1.0)


func test_population_bar_and_warning() -> void:
	var hud := _hud()
	assert_str(hud.pop_label.text).is_equal("118 / 120")
	assert_float(hud.pop_bar.max_value).is_equal(120.0)
	assert_float(hud.pop_bar.value).is_equal(118.0)
	assert_that(hud.pop_label.get_theme_color("font_color")).is_equal(MedievalTheme.BLOOD)


func test_no_settlement_shows_dashes() -> void:
	GameState.reset()
	var hud := _hud()
	assert_str(hud.settlement_name.text).is_equal("-")
	assert_str(hud.biome_badge.text).is_equal("")
	assert_str(hud.amount_of("wood").text).is_equal("0")


func test_is_in_hud_group_and_reports_height() -> void:
	var hud := _hud()
	assert_bool(hud.is_in_group("hud")).is_true()
	await await_idle_frame()
	assert_float(hud.bar_height()).is_greater(0.0)
```

- [ ] **Step 2: Uruchom, oczekuj błędów** (`settlement_name` nie istnieje)

```bash
./run_tests.sh test/scenes/hud_test.gd
```

- [ ] **Step 3: Przepisz `scenes/ui/HUD.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/ui/HUD.gd" id="1"]
[ext_resource type="Script" path="res://scenes/ui/Icon.gd" id="2"]

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

[node name="ProfileRow" type="HBoxContainer" parent="TopBar/Pad/BarRows"]
layout_mode = 2
mouse_filter = 2

[node name="Avatar" type="Control" parent="TopBar/Pad/BarRows/ProfileRow"]
layout_mode = 2
script = ExtResource("2")
kind = &"anchor"

[node name="Identity" type="VBoxContainer" parent="TopBar/Pad/BarRows/ProfileRow"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2

[node name="NameRow" type="HBoxContainer" parent="TopBar/Pad/BarRows/ProfileRow/Identity"]
layout_mode = 2
mouse_filter = 2

[node name="SettlementName" type="Label" parent="TopBar/Pad/BarRows/ProfileRow/Identity/NameRow"]
layout_mode = 2
text = "-"
clip_text = true
theme_type_variation = &"Title"

[node name="BiomeBadge" type="Label" parent="TopBar/Pad/BarRows/ProfileRow/Identity/NameRow"]
layout_mode = 2
theme_type_variation = &"Badge"

[node name="Subtitle" type="Label" parent="TopBar/Pad/BarRows/ProfileRow/Identity"]
layout_mode = 2
theme_type_variation = &"Caption"

[node name="GoldPanel" type="PanelContainer" parent="TopBar/Pad/BarRows/ProfileRow"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"Chip"

[node name="HBox" type="HBoxContainer" parent="TopBar/Pad/BarRows/ProfileRow/GoldPanel"]
layout_mode = 2
mouse_filter = 2

[node name="GoldIcon" type="Control" parent="TopBar/Pad/BarRows/ProfileRow/GoldPanel/HBox"]
layout_mode = 2
script = ExtResource("2")
kind = &"gold"

[node name="GoldLabel" type="Label" parent="TopBar/Pad/BarRows/ProfileRow/GoldPanel/HBox"]
layout_mode = 2
text = "0"
theme_type_variation = &"Amount"

[node name="ResourceGrid" type="HBoxContainer" parent="TopBar/Pad/BarRows"]
layout_mode = 2
mouse_filter = 2

[node name="PopulationRow" type="HBoxContainer" parent="TopBar/Pad/BarRows"]
layout_mode = 2
mouse_filter = 2

[node name="PopIcon" type="Control" parent="TopBar/Pad/BarRows/PopulationRow"]
layout_mode = 2
script = ExtResource("2")
kind = &"people"

[node name="PopBar" type="ProgressBar" parent="TopBar/Pad/BarRows/PopulationRow"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
mouse_filter = 2
show_percentage = false

[node name="PopLabel" type="Label" parent="TopBar/Pad/BarRows/PopulationRow"]
layout_mode = 2
text = "0 / 0"
theme_type_variation = &"Amount"
```

Uwaga: `GoldLabel` w wariacji `Amount` ma kolor `INK` na tle `OAK_DEEP`; w `_ready` nadpisujemy kolor na `CREAM` (patrz skrypt).

- [ ] **Step 4: Przepisz `scenes/ui/HUD.gd`**

```gdscript
extends CanvasLayer

## Górny pasek osady aktywnej. Nie liczy nic sam: woła Settlement.current_resources(TimeUtil.now()).
## Pokazuje wyłącznie osadę aktywną; oglądana wyspa to zadanie InspectSheet.

const NARROW_WIDTH := 700.0
const DIMMED := 0.45
const PAD := 12.0
const AVATAR := 40.0
const ICON := 24.0
const SMALL_ICON := 16.0
const POP_WARN := 0.95

@onready var top_bar: PanelContainer = $TopBar
@onready var pad: MarginContainer = $TopBar/Pad
@onready var bar_rows: VBoxContainer = $TopBar/Pad/BarRows
@onready var profile_row: HBoxContainer = $TopBar/Pad/BarRows/ProfileRow
@onready var avatar: Icon = $TopBar/Pad/BarRows/ProfileRow/Avatar
@onready var settlement_name: Label = $TopBar/Pad/BarRows/ProfileRow/Identity/NameRow/SettlementName
@onready var biome_badge: Label = $TopBar/Pad/BarRows/ProfileRow/Identity/NameRow/BiomeBadge
@onready var subtitle: Label = $TopBar/Pad/BarRows/ProfileRow/Identity/Subtitle
@onready var gold_icon: Icon = $TopBar/Pad/BarRows/ProfileRow/GoldPanel/HBox/GoldIcon
@onready var gold_label: Label = $TopBar/Pad/BarRows/ProfileRow/GoldPanel/HBox/GoldLabel
@onready var resource_grid: HBoxContainer = $TopBar/Pad/BarRows/ResourceGrid
@onready var pop_icon: Icon = $TopBar/Pad/BarRows/PopulationRow/PopIcon
@onready var pop_bar: ProgressBar = $TopBar/Pad/BarRows/PopulationRow/PopBar
@onready var pop_label: Label = $TopBar/Pad/BarRows/PopulationRow/PopLabel

var _settlement: Settlement = null
## zasób -> PanelContainer (cała karta)
var cards: Dictionary = {}
var _icons: Dictionary = {}
var _amounts: Dictionary = {}
var _rates: Dictionary = {}


func _ready() -> void:
	_style_static_nodes()
	_build_cards()
	GameState.active_settlement_changed.connect(_on_active_changed)
	GameState.settlement_updated.connect(_on_settlement_updated)
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed()
	_on_active_changed()


func _style_static_nodes() -> void:
	var p := MedievalTheme.px(PAD)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, p)
	bar_rows.add_theme_constant_override("separation", MedievalTheme.px(9))
	profile_row.add_theme_constant_override("separation", MedievalTheme.px(10))
	resource_grid.add_theme_constant_override("separation", MedievalTheme.px(6))
	avatar.custom_minimum_size = Vector2.ONE * MedievalTheme.px(AVATAR)
	avatar.color = MedievalTheme.CREAM
	gold_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(SMALL_ICON)
	gold_icon.color = MedievalTheme.BRASS
	gold_label.add_theme_color_override("font_color", MedievalTheme.CREAM)   # placeholder pod przyszłą walutę
	pop_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(SMALL_ICON)
	pop_icon.color = MedievalTheme.CREAM_SOFT
	pop_bar.custom_minimum_size.y = MedievalTheme.px(8)
	pop_label.add_theme_color_override("font_color", MedievalTheme.CREAM)


func _build_cards() -> void:
	for r in ResourceTypes.ALL:
		var card := PanelContainer.new()
		card.name = r.capitalize() + "Card"
		card.theme_type_variation = &"ResCard"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", MedievalTheme.px(2))
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


func _on_active_changed() -> void:
	_settlement = GameState.active_settlement
	if _settlement == null:
		settlement_name.text = "-"
		biome_badge.text = ""
		subtitle.text = ""
		pop_label.text = "0 / 0"
		pop_bar.value = 0.0
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
	pop_bar.max_value = maxi(_settlement.population_max, 1)
	pop_bar.value = _settlement.population
	pop_label.text = "%d / %d" % [_settlement.population, _settlement.population_max]
	var warn := _settlement.population >= float(_settlement.population_max) * POP_WARN
	pop_label.add_theme_color_override("font_color", MedievalTheme.BLOOD if warn else MedievalTheme.CREAM)


func _on_settlement_updated(coord: Vector2i) -> void:
	if _settlement != null and coord == _settlement.coord:
		_on_active_changed()


func _process(_delta: float) -> void:
	if _settlement == null:
		return
	var current := _settlement.current_resources(TimeUtil.now())
	var narrow := get_viewport().get_visible_rect().size.x < NARROW_WIDTH
	for r in ResourceTypes.ALL:
		_amounts[r].text = TimeUtil.format_amount(current[r]) if narrow else TimeUtil.format_thousands(current[r])


func _on_size_changed() -> void:
	top_bar.offset_top = SafeArea.top_inset(get_viewport())
	_apply_orientation()


## Portret: karty zasobów pod wierszem profilu. Landscape: karty w tym samym wierszu po prawej,
## żeby obszar gry zachował wysokość.
func _apply_orientation() -> void:
	var vis := get_viewport().get_visible_rect().size
	var landscape := vis.x > vis.y
	var parent := resource_grid.get_parent()
	if landscape and parent != profile_row:
		parent.remove_child(resource_grid)
		profile_row.add_child(resource_grid)
		resource_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif not landscape and parent != bar_rows:
		parent.remove_child(resource_grid)
		bar_rows.add_child(resource_grid)
		bar_rows.move_child(resource_grid, 1)
		resource_grid.size_flags_horizontal = Control.SIZE_FILL
```

- [ ] **Step 5: Dostosuj smoke probe** (`tools/smoke_probe.gd`)

Zamień `_chip_icon_center`:

```gdscript
## Środek ikony drewna w pasku HUD (piksele viewportu).
func _chip_icon_center(hud: CanvasLayer) -> Vector2:
	return (hud.icon_of("wood") as Control).get_global_rect().get_center()
```

W klatce `49` zamień dwie linie HUD na:

```gdscript
				_check(hud.settlement_name.text == "Koralowa", "HUD pokazuje osadę aktywną")
				_check(hud.pop_label.text == "42 / 120", "HUD pokazuje populację")
```

Zaktualizuj komentarz przy `BAR_DRAG_DELTA` (pasek ma teraz ok. 400 px, ale gest zostaje poziomy, żeby na pewno nie opuścić paska).

- [ ] **Step 6: Uruchom testy i smoke**

```bash
./run_tests.sh test/scenes/hud_test.gd
./run_smoke.sh
```

Oczekiwane: 5 testów zielonych, `SMOKE PASSED`. Jeśli `bar_height()` w teście zwraca 0, dodaj drugi `await await_idle_frame()`: kontener liczy rozmiar w pierwszej klatce po dodaniu.

- [ ] **Step 7: Commit**

```bash
git add scenes/ui/HUD.tscn scenes/ui/HUD.gd tools/smoke_probe.gd test/scenes/hud_test.gd test/scenes/hud_test.gd.uid
git commit -m "Restyle the HUD top bar: profile row, five resource cards, population bar"
```

---

### Task 6: Pamięć kamery, `show_world_map_at`, fade widoku, `zoom_by`

**Files:**
- Modify: `scenes/autoload/SceneManager.gd` (całość), `scenes/views/WorldMap.gd:22-30` (`_ready`) + nowe `focus`, `_exit_tree`, `scenes/views/MapCamera.gd:96` (nowe `zoom_by`)
- Test: `test/scenes/map_camera_test.gd`, `test/scenes/world_map_test.gd`

**Interfaces:**
- Produces: `SceneManager.map_camera_state: Dictionary` (`position: Vector2`, `zoom: Vector2`), `SceneManager.show_world_map_at(world_pos: Vector2)`, `SceneManager.FADE_TIME`, `WorldMap.focus(world_pos: Vector2)`, `MapCamera.zoom_by(factor: float)`.

- [ ] **Step 1: Testy**

Dopisz do `test/scenes/map_camera_test.gd`:

```gdscript
func test_zoom_by_keeps_screen_center() -> void:
	var cam := _camera()
	cam.position = Vector2(500, 500)
	cam.zoom_by(1.25)
	assert_float(cam.zoom.x).is_equal_approx(1.25, 0.001)
	assert_that(cam.position).is_equal_approx(Vector2(500, 500), Vector2(0.01, 0.01))
```

Dopisz do `test/scenes/world_map_test.gd` (przed pierwszym `test_`):

```gdscript
func test_map_saves_camera_state_on_exit_and_restores_it() -> void:
	_apply_world()
	SceneManager.map_camera_state.clear()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	var camera: MapCamera = world_map.camera
	camera.position = START_POS + Vector2(1234.0, 567.0)
	camera.zoom = Vector2(0.5, 0.5)
	var saved_pos := camera.position
	remove_child(world_map)
	assert_that(SceneManager.map_camera_state.get("position")).is_equal(saved_pos)
	assert_that(SceneManager.map_camera_state.get("zoom")).is_equal(Vector2(0.5, 0.5))

	var again := _spawn_map(Vector2.ZERO)
	await _settle(again)
	assert_that((again.camera as MapCamera).position).is_equal(saved_pos)
	assert_that((again.camera as MapCamera).zoom).is_equal(Vector2(0.5, 0.5))
	SceneManager.map_camera_state.clear()


func test_focus_moves_camera_and_kills_inertia() -> void:
	_apply_world()
	SceneManager.map_camera_state.clear()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	var target := START_POS + Vector2(5000.0, -3000.0)
	world_map.focus(target)
	assert_that((world_map.camera as MapCamera).position).is_equal(target)
	assert_that((world_map.camera as MapCamera)._velocity).is_equal(Vector2.ZERO)
```

Uwaga: `_spawn_map` ustawia pozycję kamery przed `add_child`, a `_ready()` mapy nadpisuje ją zapamiętanym stanem; dlatego pierwszy test czyści `map_camera_state` na początku, a istniejące testy nie ruszają stanu (pusty słownik = zachowanie jak dziś). Dodaj `SceneManager.map_camera_state.clear()` do `before_test()` i `after_test()` tego pliku.

- [ ] **Step 2: Uruchom, oczekuj błędów** (`map_camera_state`, `zoom_by`, `focus` nie istnieją)

```bash
./run_tests.sh test/scenes/map_camera_test.gd
./run_tests.sh test/scenes/world_map_test.gd
```

- [ ] **Step 3: `MapCamera.zoom_by`** (dopisz przed `_zoom_at`)

```gdscript
## Zoom wokół środka ekranu (przyciski + / − na mapie).
func zoom_by(factor: float) -> void:
	_zoom_at(get_viewport_rect().size / 2.0, factor)
```

- [ ] **Step 4: `SceneManager.gd`** (całość)

```gdscript
extends Node

signal view_changed(view_path: String)

const VIEW_WORLD_MAP := "res://scenes/views/WorldMap.tscn"
const VIEW_ISLAND_DETAIL := "res://scenes/views/IslandDetail.tscn"
const FADE_TIME := 0.18

var current_view: String = ""
## Ostatnia pozycja i zoom kamery mapy: WorldMap zapisuje przy wyjściu, odczytuje przy wejściu.
## Pusty słownik = mapa centruje na osadzie aktywnej.
var map_camera_state: Dictionary = {}
var _container: Node = null
var _current: Node = null
var _fade: Tween = null


func register_container(container: Node) -> void:
	_container = container


func show_world_map() -> void:
	_swap(VIEW_WORLD_MAP)


func show_island_detail() -> void:
	_swap(VIEW_ISLAND_DETAIL)


## Otwiera mapę wycentrowaną na punkcie świata; gdy mapa już jest otwarta, tylko przesuwa kamerę.
func show_world_map_at(world_pos: Vector2) -> void:
	if current_view == VIEW_WORLD_MAP and _current != null:
		_current.focus(world_pos)
		return
	map_camera_state["position"] = world_pos
	_swap(VIEW_WORLD_MAP)


func _swap(path: String) -> void:
	if _container == null:
		push_error("SceneManager: brak kontenera widoków (register_container)")
		return
	if path == current_view and _current != null:
		return
	if _current != null:
		_current.queue_free()
	var scene: PackedScene = load(path)
	_current = scene.instantiate()
	_container.add_child(_current)
	current_view = path
	_fade_in(_current)
	view_changed.emit(path)


## Wchodzący widok pojawia się przez fade; wychodzący znika od razu (tween na węźle
## czekającym na queue_free to źródło błędów, a przy fade wchodzącego różnicy nie widać).
func _fade_in(view: Node) -> void:
	if not (view is CanvasItem):
		return
	if _fade != null and _fade.is_running():
		_fade.kill()
	view.modulate.a = 0.0
	_fade = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade.tween_property(view, "modulate:a", 1.0, FADE_TIME)
```

- [ ] **Step 5: `WorldMap.gd`**: zamień `_ready` i dodaj `focus`, `_exit_tree`

```gdscript
func _ready() -> void:
	camera.tapped.connect(_on_tapped)
	GameState.settlement_updated.connect(_on_settlement_updated)
	GameState.fleets_updated.connect(fleets.refresh)
	var saved: Dictionary = SceneManager.map_camera_state
	if saved.has("position"):
		camera.position = saved["position"]
	elif GameState.active_settlement != null:
		camera.position = WorldGrid.cell_to_world(GameState.active_settlement.coord)
	if saved.has("zoom"):
		camera.zoom = saved["zoom"]
	if GameState.world != null:
		camera.set_bounds(Rect2(Vector2.ZERO, Vector2(GameState.world.size) * WorldGrid.CELL_SIZE))
	_rebuild_labels()
	_refresh_chunks()


func _exit_tree() -> void:
	SceneManager.map_camera_state["position"] = camera.position
	SceneManager.map_camera_state["zoom"] = camera.zoom


## Natychmiastowy skok kamery (arkusz flot). Zeruje inercję, żeby kamera nie odjechała.
func focus(world_pos: Vector2) -> void:
	camera.position = world_pos
	camera._velocity = Vector2.ZERO
	camera._clamp_position()
```

- [ ] **Step 6: Uruchom testy i smoke**

```bash
./run_tests.sh test/scenes
./run_smoke.sh
```

Oczekiwane: zielono. Smoke dalej startuje na mapie i przechodzi mapa → detal → mapa; po powrocie kamera wraca w zapamiętane miejsce, co nie psuje żadnego sprawdzenia.

- [ ] **Step 7: Commit**

```bash
git add scenes/autoload/SceneManager.gd scenes/views/WorldMap.gd scenes/views/MapCamera.gd test/scenes/map_camera_test.gd test/scenes/world_map_test.gd
git commit -m "Remember map camera between views, add show_world_map_at, focus and zoom_by"
```

---

### Task 7: `SlotPlaque` i sloty generatora

**Files:**
- Create: `scenes/procedural/SlotPlaque.gd`
- Modify: `scenes/procedural/IslandGenerator.gd:13-20,62-66,125-156,166-170`
- Test: `test/scenes/slot_plaque_test.gd`, `test/scenes/island_generator_test.gd`

**Interfaces:**
- Consumes: `Icon`, `Buildings.icon`, `MedievalTheme.*`.
- Produces: `class_name SlotPlaque extends Node2D` z `const WIDTH`, `HEIGHT`, `PRESS_TRAVEL`, `var building: int`, `var level: int`, `var pressed: bool`, `func setup(building: int, level: int)`, `func contains(local: Vector2) -> bool`; dzieci `Icon` (nazwa `Icon`) i `Label` (nazwa `Level`). `IslandGenerator.set_pressed(t: int, pressed: bool)`, `IslandGenerator.clear()`; `slot_at` liczy trafienie prostokątem plakietki.

- [ ] **Step 1: Testy**

`test/scenes/slot_plaque_test.gd`:

```gdscript
extends GdUnitTestSuite


func _plaque(building: int, level: int) -> SlotPlaque:
	var p: SlotPlaque = auto_free(SlotPlaque.new())
	p.setup(building, level)
	add_child(p)
	return p


func test_built_slot_shows_icon_and_level() -> void:
	var p := _plaque(Buildings.Type.SAWMILL, 3)
	assert_str(String((p.get_node("Icon") as Icon).kind)).is_equal("wood")
	assert_str((p.get_node("Level") as Label).text).is_equal("LV 3")
	assert_bool((p.get_node("Level") as Label).visible).is_true()


func test_empty_slot_shows_plus_without_level() -> void:
	var p := _plaque(Buildings.Type.BARRACKS, 0)
	assert_str(String((p.get_node("Icon") as Icon).kind)).is_equal("plus")
	assert_bool((p.get_node("Level") as Label).visible).is_false()


func test_contains_is_rectangular() -> void:
	var p := _plaque(Buildings.Type.TOWN_HALL, 1)
	assert_bool(p.contains(Vector2.ZERO)).is_true()
	assert_bool(p.contains(Vector2(SlotPlaque.WIDTH / 2.0 - 1.0, 0.0))).is_true()
	assert_bool(p.contains(Vector2(SlotPlaque.WIDTH / 2.0 + 1.0, 0.0))).is_false()
	assert_bool(p.contains(Vector2(0.0, SlotPlaque.HEIGHT / 2.0 + 1.0))).is_false()


func test_pressed_moves_children_down() -> void:
	var p := _plaque(Buildings.Type.TOWN_HALL, 1)
	var before: float = (p.get_node("Icon") as Control).position.y
	p.pressed = true
	assert_float((p.get_node("Icon") as Control).position.y).is_equal(before + SlotPlaque.PRESS_TRAVEL)
	p.pressed = false
	assert_float((p.get_node("Icon") as Control).position.y).is_equal(before)
```

W `test/scenes/island_generator_test.gd` zamień `test_settlement_levels_reach_labels` na:

```gdscript
func test_settlement_levels_reach_plaques() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	var s := Settlement.from_json({"x": 1, "y": 1, "resources": {}, "buildings": {"SAWMILL": 3}}, Biome.Type.TROPICAL)
	gen.settlement = s
	gen.build()
	var plaque: SlotPlaque = gen.get_node("Slot_SAWMILL")
	assert_int(plaque.level).is_equal(3)
	assert_str((plaque.get_node("Level") as Label).text).is_equal("LV 3")
	assert_int((gen.get_node("Slot_FARM") as SlotPlaque).level).is_equal(0)


func test_slot_at_uses_plaque_rectangle_at_detail_radius() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	gen.radius = 400.0
	gen.build()
	assert_int(gen.slot_at(Vector2.ZERO)).is_equal(Buildings.Type.TOWN_HALL)
	assert_int(gen.slot_at(Vector2(SlotPlaque.WIDTH / 2.0 - 1.0, 0.0))).is_equal(Buildings.Type.TOWN_HALL)
	# między plakietką ratusza (do 77 px) a pierścieniem slotów (od 180 - 80 = 100 px) jest pusto
	assert_int(gen.slot_at(Vector2(0.0, 90.0))).is_equal(-1)
	for t in gen._slot_positions:
		assert_int(gen.slot_at(gen._slot_positions[t])).is_equal(t)


func test_set_pressed_reaches_plaque() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	gen.set_pressed(Buildings.Type.TOWN_HALL, true)
	assert_bool((gen.get_node("Slot_TOWN_HALL") as SlotPlaque).pressed).is_true()
	gen.set_pressed(Buildings.Type.TOWN_HALL, false)
	assert_bool((gen.get_node("Slot_TOWN_HALL") as SlotPlaque).pressed).is_false()


func test_clear_removes_everything() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	gen.clear()
	assert_int(gen.get_child_count()).is_equal(0)
	assert_int(gen.slot_at(Vector2.ZERO)).is_equal(-1)
```

- [ ] **Step 2: Uruchom, oczekuj błędów**

```bash
./run_tests.sh test/scenes/slot_plaque_test.gd
./run_tests.sh test/scenes/island_generator_test.gd
```

- [ ] **Step 3: Napisz `scenes/procedural/SlotPlaque.gd`**

```gdscript
class_name SlotPlaque
extends Node2D

## Slot budynku jako rzeźbiona plakietka: pergaminowa twarz, dębowa krawędź, twardy cień.
## Rozmiar stały w pikselach świata; kamera osady nie zoomuje, więc na ekranie wygląda jak w mocku.
## Poziom 0: półprzezroczysta twarz z przerywaną krawędzią i ikoną plus.

const WIDTH := 160.0
const HEIGHT := 155.0
const RADIUS := 14
const BORDER := 6
const SHADOW := 8.0
const PRESS_TRAVEL := 8.0
const ICON_SIZE := 56.0
const DASH := 12.0
const EMPTY_ALPHA := 0.35

var building: int = -1
var level: int = 0
var pressed: bool = false:
	set(v):
		if pressed == v:
			return
		pressed = v
		_place_children()
		queue_redraw()

var _face: StyleBoxFlat
var _shadow: StyleBoxFlat
var _icon: Icon
var _label: Label


func _init() -> void:
	_face = StyleBoxFlat.new()
	_face.bg_color = MedievalTheme.PARCHMENT
	_face.set_corner_radius_all(RADIUS)
	_face.border_color = MedievalTheme.OAK
	_face.set_border_width_all(BORDER)
	_face.anti_aliasing = true
	_shadow = StyleBoxFlat.new()
	_shadow.bg_color = MedievalTheme.OAK_DEEP
	_shadow.set_corner_radius_all(RADIUS)
	_shadow.anti_aliasing = true
	_icon = Icon.new()
	_icon.name = "Icon"
	_icon.size = Vector2.ONE * ICON_SIZE
	add_child(_icon)
	_label = Label.new()
	_label.name = "Level"
	_label.theme_type_variation = &"Badge"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func setup(t: int, lvl: int) -> void:
	building = t
	level = lvl
	if level > 0:
		_icon.kind = Buildings.icon(t)
		_icon.color = MedievalTheme.INK
		_label.text = "LV %d" % level
		_label.visible = true
	else:
		_icon.kind = &"plus"
		_icon.color = MedievalTheme.OAK_DEEP
		_label.visible = false
	_label.reset_size()
	_place_children()
	queue_redraw()


func _place_children() -> void:
	var dy := PRESS_TRAVEL if pressed else 0.0
	if level > 0:
		_icon.position = Vector2(-ICON_SIZE / 2.0, -HEIGHT / 2.0 + 22.0 + dy)
		_label.position = Vector2(-_label.size.x / 2.0, HEIGHT / 2.0 - _label.size.y - 18.0 + dy)
	else:
		_icon.position = Vector2(-ICON_SIZE / 2.0, -ICON_SIZE / 2.0 + dy)


## Trafienie liczone samą twarzą plakietki, bez cienia.
func contains(local: Vector2) -> bool:
	return Rect2(-WIDTH / 2.0, -HEIGHT / 2.0, WIDTH, HEIGHT).has_point(local)


func _draw() -> void:
	var rect := Rect2(-WIDTH / 2.0, -HEIGHT / 2.0, WIDTH, HEIGHT)
	if level > 0:
		if not pressed:
			_shadow.draw(get_canvas_item(), Rect2(rect.position + Vector2(0, SHADOW), rect.size))
		_face.draw(get_canvas_item(), Rect2(rect.position + Vector2(0, PRESS_TRAVEL if pressed else 0.0), rect.size))
		return
	draw_rect(rect, Color(MedievalTheme.PARCHMENT, EMPTY_ALPHA))
	var c := MedievalTheme.OAK_EDGE
	draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), c, 3.0, DASH, true)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, c, 3.0, DASH, true)
	draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), c, 3.0, DASH, true)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, c, 3.0, DASH, true)
```

- [ ] **Step 4: Zmiany w `IslandGenerator.gd`**

Usuń stałe `SLOT_SIZE`, `SLOT_HIT`, `EMPTY_SLOT_FILL`, `EMPTY_SLOT_LINE` oraz statyczną `hexagon()`. Wydziel `clear()` z `build()`:

```gdscript
func clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_slot_positions.clear()


func build() -> void:
	clear()
	_coast = CoastlineGenerator.generate(seed_val, radius, POINTS)
	# ... reszta build() bez zmian ...
```

Zamień `_add_slot`, `slot_at` i dodaj `set_pressed`:

```gdscript
func _add_slot(t: Buildings.Type, pos: Vector2) -> void:
	var lvl := settlement.level(t) if settlement != null else 0
	var plaque := SlotPlaque.new()
	plaque.name = "Slot_" + Buildings.key(t)
	plaque.position = pos
	plaque.setup(t, lvl)
	add_child(plaque)


## Typ budynku pod pozycją lokalną (prostokąt plakietki) albo -1.
func slot_at(local_pos: Vector2) -> int:
	for t in _slot_positions:
		var plaque := _plaque(t)
		if plaque != null and plaque.contains(local_pos - _slot_positions[t]):
			return t
	return -1


func set_pressed(t: int, pressed: bool) -> void:
	var plaque := _plaque(t)
	if plaque != null:
		plaque.pressed = pressed


func _plaque(t: int) -> SlotPlaque:
	return get_node_or_null("Slot_" + Buildings.key(t)) as SlotPlaque
```

Zaktualizuj komentarz nagłówkowy pliku: sloty rysuje `SlotPlaque`.

- [ ] **Step 5: Uruchom testy i smoke**

```bash
./run_tests.sh test/scenes
./run_smoke.sh
```

Oczekiwane: zielono. Smoke klika slot ratusza przez `_slot_positions`, co dalej trafia w środek plakietki.

- [ ] **Step 6: Commit**

```bash
git add scenes/procedural/SlotPlaque.gd scenes/procedural/SlotPlaque.gd.uid scenes/procedural/IslandGenerator.gd test/scenes/slot_plaque_test.gd test/scenes/slot_plaque_test.gd.uid test/scenes/island_generator_test.gd
git commit -m "Draw building slots as carved plaques with rectangular hit test"
```

---

### Task 8: `Sheets`, `BuildingSheet`, widok osady bez menu

**Files:**
- Create: `scenes/ui/Sheets.tscn`, `scenes/ui/Sheets.gd`, `scenes/ui/SheetStyle.gd`, `scenes/ui/BuildingSheet.tscn`, `scenes/ui/BuildingSheet.gd`
- Modify: `scenes/views/IslandDetail.tscn` (całość), `scenes/views/IslandDetail.gd` (całość), `scenes/views/Main.tscn` (instancja `Sheets`), `scenes/views/Main.gd` (sygnał `upgrade_requested`), `tools/smoke_probe.gd:163-210`
- Delete: `scenes/ui/BuildingMenu.tscn`, `scenes/ui/BuildingMenu.gd`, `scenes/ui/BuildingMenu.gd.uid`
- Test: `test/scenes/sheets_test.gd`, `test/scenes/building_sheet_test.gd`, `./run_smoke.sh`

**Interfaces:**
- Consumes: `MedievalTheme`, `Icon.into_button`, `SafeArea`, `SlotPlaque`, `IslandGenerator.slot_at/set_pressed/clear`, `HUD.bar_height()` (grupa `hud`), `SceneManager.view_changed`.
- Produces: `Sheets` (`CanvasLayer`, grupa `sheets`) z `open_fleets()` (działa dopiero od Task 10; do tego czasu zgłasza `push_warning`), `open_inspect(coord: Vector2i) -> bool` (Task 9), `open_building(settlement: Settlement, building: int) -> bool`, `close()`, `is_open() -> bool`, `current_sheet() -> Control`, sygnał `upgrade_requested(coord: Vector2i, building: int)`; pola `backdrop`, `building_sheet`. `BuildingSheet` (`PanelContainer`) z `open(settlement, building) -> bool`, `refresh_costs(costs: Dictionary, stock: Dictionary)`, `refresh_timer(remaining: float, total: float)`, sygnały `upgrade_requested(coord, building)`, `close_requested`; pola `name_label`, `level_badge`, `subtitle`, `description`, `cost_section`, `timer_section`, `timer_label`, `construction_bar`, `upgrade_button`, `cancel_button`, `close_button`, `cost_chips: Dictionary`.

- [ ] **Step 1: Testy**

`test/scenes/building_sheet_test.gd`:

```gdscript
extends GdUnitTestSuite

const SHEET := preload("res://scenes/ui/BuildingSheet.tscn")


func _settlement() -> Settlement:
	return Settlement.from_json({
		"x": 103, "y": 100, "ownerId": 7, "name": "Koralowa",
		"resources": {"wood": 100}, "buildings": {"TOWN_HALL": 1, "SAWMILL": 2},
	}, Biome.Type.TROPICAL)


func _sheet() -> BuildingSheet:
	var s: BuildingSheet = auto_free(SHEET.instantiate())
	add_child(s)
	return s


func test_open_fills_header_and_hides_cost_and_timer() -> void:
	var s := _sheet()
	assert_bool(s.open(_settlement(), Buildings.Type.SAWMILL)).is_true()
	assert_str(s.name_label.text).is_equal("Tartak")
	assert_str(s.level_badge.text).is_equal("LV 2")
	assert_str(s.subtitle.text).is_equal("Koralowa · slot 5 z 6")
	assert_str(s.description.text).is_equal(Buildings.DESCRIPTIONS[Buildings.Type.SAWMILL])
	assert_str(s.upgrade_button.text).is_equal("ULEPSZ")
	assert_bool(s.cost_section.visible).is_false()
	assert_bool(s.timer_section.visible).is_false()
	assert_bool(s.upgrade_button.disabled).is_false()


func test_empty_slot_offers_build() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.BARRACKS)
	assert_str(s.level_badge.text).is_equal("LV 0")
	assert_str(s.upgrade_button.text).is_equal("BUDUJ")


func test_building_outside_biome_is_rejected() -> void:
	var s := _sheet()
	await assert_error(func() -> void: s.open(_settlement(), Buildings.Type.IRON_MINE)) \
		.is_push_error("BuildingSheet: budynek IRON_MINE poza slotami biomu TROPICAL")


func test_refresh_costs_marks_short_resources() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.SAWMILL)
	s.refresh_costs({"wood": 50, "stone": 200}, {"wood": 100, "stone": 20})
	assert_bool(s.cost_section.visible).is_true()
	assert_bool(s.cost_chips["wood"].visible).is_true()
	assert_bool(s.cost_chips["food"].visible).is_false()
	var stone_chip: PanelContainer = s.cost_chips["stone"]
	var sb: StyleBoxFlat = stone_chip.get_theme_stylebox("panel")
	assert_that(sb.bg_color).is_equal(MedievalTheme.SHORT_BG)
	assert_str(s.cost_header.text).is_equal("KOSZT ULEPSZENIA DO 3")


func test_refresh_timer_disables_upgrade_until_done() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.SAWMILL)
	s.refresh_timer(90.0, 180.0)
	assert_bool(s.timer_section.visible).is_true()
	assert_str(s.timer_label.text).is_equal("00:01:30")
	assert_float(s.construction_bar.value).is_equal_approx(0.5, 0.001)
	assert_bool(s.upgrade_button.disabled).is_true()
	s.refresh_timer(0.0, 180.0)
	assert_bool(s.upgrade_button.disabled).is_false()


func test_upgrade_emits_coord_and_building() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.SAWMILL)
	var got: Array = []
	s.upgrade_requested.connect(func(c: Vector2i, b: int) -> void: got.append([c, b]))
	s.upgrade_button.pressed.emit()
	assert_that(got).is_equal([[Vector2i(103, 100), Buildings.Type.SAWMILL]])
```

`test/scenes/sheets_test.gd`:

```gdscript
extends GdUnitTestSuite

const SHEETS := preload("res://scenes/ui/Sheets.tscn")


func before_test() -> void:
	GameState.reset()


func after_test() -> void:
	GameState.reset()


func _sheets() -> CanvasLayer:
	var s: CanvasLayer = auto_free(SHEETS.instantiate())
	add_child(s)
	return s


func _settlement() -> Settlement:
	return Settlement.from_json({
		"x": 103, "y": 100, "ownerId": 7, "name": "Koralowa", "resources": {},
	}, Biome.Type.TROPICAL)


func test_starts_closed_and_hidden() -> void:
	var s := _sheets()
	assert_bool(s.visible).is_false()
	assert_bool(s.is_open()).is_false()
	assert_bool(s.is_in_group("sheets")).is_true()


func test_open_building_shows_layer_and_sheet() -> void:
	var s := _sheets()
	assert_bool(s.open_building(_settlement(), Buildings.Type.TOWN_HALL)).is_true()
	assert_bool(s.visible).is_true()
	assert_bool(s.is_open()).is_true()
	assert_object(s.current_sheet()).is_same(s.building_sheet)
	assert_bool(s.building_sheet.visible).is_true()


func test_rejected_building_keeps_layer_closed() -> void:
	var s := _sheets()
	await assert_error(func() -> void: s.open_building(_settlement(), Buildings.Type.IRON_MINE)) \
		.is_push_error("BuildingSheet: budynek IRON_MINE poza slotami biomu TROPICAL")
	assert_bool(s.is_open()).is_false()
	assert_bool(s.visible).is_false()


func test_close_hides_layer_after_animation() -> void:
	var s := _sheets()
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	s.close()
	assert_bool(s.is_open()).is_false()
	await await_millis(500)
	assert_bool(s.visible).is_false()
	assert_bool(s.building_sheet.visible).is_false()


func test_backdrop_touch_closes() -> void:
	var s := _sheets()
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	s.backdrop.gui_input.emit(touch)
	assert_bool(s.is_open()).is_false()


func test_view_change_closes_immediately() -> void:
	var s := _sheets()
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	SceneManager.view_changed.emit("x")
	assert_bool(s.is_open()).is_false()
	assert_bool(s.visible).is_false()


func test_upgrade_is_forwarded_and_closes() -> void:
	var s := _sheets()
	var got: Array = []
	s.upgrade_requested.connect(func(c: Vector2i, b: int) -> void: got.append(b))
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	s.building_sheet.upgrade_button.pressed.emit()
	assert_that(got).is_equal([Buildings.Type.TOWN_HALL])
	assert_bool(s.is_open()).is_false()
```

- [ ] **Step 2: Uruchom, oczekuj błędów** (sceny nie istnieją)

```bash
./run_tests.sh test/scenes/building_sheet_test.gd
./run_tests.sh test/scenes/sheets_test.gd
```

- [ ] **Step 3: `scenes/ui/BuildingSheet.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/ui/BuildingSheet.gd" id="1"]
[ext_resource type="Script" path="res://scenes/ui/Icon.gd" id="2"]

[node name="BuildingSheet" type="PanelContainer"]
visible = false
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 0
mouse_filter = 0
theme_type_variation = &"Sheet"
script = ExtResource("1")

[node name="SheetMargin" type="MarginContainer" parent="."]
layout_mode = 2
mouse_filter = 2

[node name="ModalBody" type="VBoxContainer" parent="SheetMargin"]
layout_mode = 2
mouse_filter = 2

[node name="Grabber" type="Panel" parent="SheetMargin/ModalBody"]
layout_mode = 2
size_flags_horizontal = 4
mouse_filter = 2

[node name="Header" type="PanelContainer" parent="SheetMargin/ModalBody"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"ModalHeader"

[node name="HBox" type="HBoxContainer" parent="SheetMargin/ModalBody/Header"]
layout_mode = 2
mouse_filter = 2

[node name="BuildingIcon" type="Control" parent="SheetMargin/ModalBody/Header/HBox"]
layout_mode = 2
script = ExtResource("2")

[node name="TitleBox" type="VBoxContainer" parent="SheetMargin/ModalBody/Header/HBox"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2

[node name="NameRow" type="HBoxContainer" parent="SheetMargin/ModalBody/Header/HBox/TitleBox"]
layout_mode = 2
mouse_filter = 2

[node name="Name" type="Label" parent="SheetMargin/ModalBody/Header/HBox/TitleBox/NameRow"]
layout_mode = 2
theme_type_variation = &"Title"

[node name="LevelBadge" type="Label" parent="SheetMargin/ModalBody/Header/HBox/TitleBox/NameRow"]
layout_mode = 2
theme_type_variation = &"Badge"

[node name="Subtitle" type="Label" parent="SheetMargin/ModalBody/Header/HBox/TitleBox"]
layout_mode = 2
theme_type_variation = &"Caption"

[node name="CloseButton" type="Button" parent="SheetMargin/ModalBody/Header/HBox"]
layout_mode = 2
size_flags_vertical = 4
theme_type_variation = &"ToolButton"

[node name="Description" type="Label" parent="SheetMargin/ModalBody"]
layout_mode = 2
autowrap_mode = 3

[node name="CostSection" type="VBoxContainer" parent="SheetMargin/ModalBody"]
visible = false
layout_mode = 2
mouse_filter = 2

[node name="CostHeader" type="Label" parent="SheetMargin/ModalBody/CostSection"]
layout_mode = 2
theme_type_variation = &"SectionHeader"

[node name="CostGrid" type="GridContainer" parent="SheetMargin/ModalBody/CostSection"]
layout_mode = 2
columns = 5
mouse_filter = 2

[node name="TimerSection" type="VBoxContainer" parent="SheetMargin/ModalBody"]
visible = false
layout_mode = 2
mouse_filter = 2

[node name="TimerRow" type="HBoxContainer" parent="SheetMargin/ModalBody/TimerSection"]
layout_mode = 2
mouse_filter = 2

[node name="TimerHeader" type="Label" parent="SheetMargin/ModalBody/TimerSection/TimerRow"]
layout_mode = 2
size_flags_horizontal = 3
text = "BUDOWA"
theme_type_variation = &"SectionHeader"

[node name="TimerLabel" type="Label" parent="SheetMargin/ModalBody/TimerSection/TimerRow"]
layout_mode = 2
theme_type_variation = &"Amount"

[node name="ConstructionBar" type="ProgressBar" parent="SheetMargin/ModalBody/TimerSection"]
layout_mode = 2
mouse_filter = 2
max_value = 1.0
show_percentage = false

[node name="ActionRow" type="HBoxContainer" parent="SheetMargin/ModalBody"]
layout_mode = 2
mouse_filter = 2

[node name="CancelButton" type="Button" parent="SheetMargin/ModalBody/ActionRow"]
layout_mode = 2
size_flags_horizontal = 3
text = "ZAMKNIJ"
theme_type_variation = &"Danger"

[node name="UpgradeButton" type="Button" parent="SheetMargin/ModalBody/ActionRow"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_stretch_ratio = 2.0
text = "ULEPSZ"
theme_type_variation = &"Primary"
```

- [ ] **Step 4: `scenes/ui/BuildingSheet.gd`**

```gdscript
class_name BuildingSheet
extends PanelContainer

## Arkusz budynku: nazwa, poziom, opis, ZAMKNIJ / ULEPSZ. Bez logiki ulepszania.
## Sekcje kosztu i licznika istnieją, ale są ukryte, dopóki API ich nie zasili
## (refresh_costs / refresh_timer są publiczne właśnie na ten moment).

signal upgrade_requested(coord: Vector2i, building: int)
signal close_requested

const ICON := 46.0
const CLOSE := 30.0
const CHIP_ICON := 13.0

@onready var grabber: Panel = $SheetMargin/ModalBody/Grabber
@onready var building_icon: Icon = $SheetMargin/ModalBody/Header/HBox/BuildingIcon
@onready var name_label: Label = $SheetMargin/ModalBody/Header/HBox/TitleBox/NameRow/Name
@onready var level_badge: Label = $SheetMargin/ModalBody/Header/HBox/TitleBox/NameRow/LevelBadge
@onready var subtitle: Label = $SheetMargin/ModalBody/Header/HBox/TitleBox/Subtitle
@onready var close_button: Button = $SheetMargin/ModalBody/Header/HBox/CloseButton
@onready var description: Label = $SheetMargin/ModalBody/Description
@onready var cost_section: VBoxContainer = $SheetMargin/ModalBody/CostSection
@onready var cost_header: Label = $SheetMargin/ModalBody/CostSection/CostHeader
@onready var cost_grid: GridContainer = $SheetMargin/ModalBody/CostSection/CostGrid
@onready var timer_section: VBoxContainer = $SheetMargin/ModalBody/TimerSection
@onready var timer_label: Label = $SheetMargin/ModalBody/TimerSection/TimerRow/TimerLabel
@onready var construction_bar: ProgressBar = $SheetMargin/ModalBody/TimerSection/ConstructionBar
@onready var cancel_button: Button = $SheetMargin/ModalBody/ActionRow/CancelButton
@onready var upgrade_button: Button = $SheetMargin/ModalBody/ActionRow/UpgradeButton

## zasób -> PanelContainer (chip kosztu)
var cost_chips: Dictionary = {}
var _cost_labels: Dictionary = {}
var _settlement: Settlement = null
var _building: int = -1
var _remaining := 0.0
var _total := 0.0


func _ready() -> void:
	SheetStyle.apply_common(self, grabber)
	building_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
	building_icon.color = MedievalTheme.CREAM
	close_button.custom_minimum_size = Vector2.ONE * MedievalTheme.px(CLOSE)
	Icon.into_button(close_button, &"close", MedievalTheme.CREAM, MedievalTheme.px(7))
	for b in [cancel_button, upgrade_button]:
		b.custom_minimum_size.y = MedievalTheme.px(48)
	cost_grid.add_theme_constant_override("h_separation", MedievalTheme.px(6))
	_build_cost_chips()
	close_button.pressed.connect(func() -> void: close_requested.emit())
	cancel_button.pressed.connect(func() -> void: close_requested.emit())
	upgrade_button.pressed.connect(_on_upgrade)
	set_process(false)


func _build_cost_chips() -> void:
	for r in ResourceTypes.ALL:
		var chip := PanelContainer.new()
		chip.name = r.capitalize() + "Cost"
		chip.theme_type_variation = &"Chip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := HBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Icon.new()
		icon.kind = ResourceTypes.ICONS[r]
		icon.color = ResourceTypes.COLORS[r]
		icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(CHIP_ICON)
		var amount := Label.new()
		amount.name = "Amount"
		amount.theme_type_variation = &"Amount"
		box.add_child(icon)
		box.add_child(amount)
		chip.add_child(box)
		cost_grid.add_child(chip)
		cost_chips[r] = chip
		_cost_labels[r] = amount


## Zwraca false (i push_error) dla budynku spoza slotów biomu osady.
func open(settlement: Settlement, building: int) -> bool:
	var slots := Biome.slots(settlement.biome)
	if not slots.has(building):
		push_error("BuildingSheet: budynek %s poza slotami biomu %s" % [Buildings.key(building), Biome.key(settlement.biome)])
		return false
	_settlement = settlement
	_building = building
	var level := settlement.level(building)
	building_icon.kind = Buildings.icon(building)
	name_label.text = Buildings.label(building)
	level_badge.text = "LV %d" % level
	subtitle.text = "%s · slot %d z %d" % [settlement.name, slots.find(building) + 1, slots.size()]
	description.text = Buildings.DESCRIPTIONS[building]
	upgrade_button.text = "BUDUJ" if level == 0 else "ULEPSZ"
	upgrade_button.disabled = false
	cost_section.hide()
	timer_section.hide()
	set_process(false)
	return true


## Pokazuje sekcję kosztu; chip zasobu widoczny, gdy koszt > 0; brakujący zasób na czerwono.
func refresh_costs(costs: Dictionary, stock: Dictionary) -> void:
	cost_header.text = "KOSZT ULEPSZENIA DO %d" % (_settlement.level(_building) + 1 if _settlement != null else 1)
	for r in ResourceTypes.ALL:
		var required := float(costs.get(r, 0.0))
		var held := float(stock.get(r, 0.0))
		var chip: PanelContainer = cost_chips[r]
		chip.visible = required > 0.0
		_cost_labels[r].text = TimeUtil.format_thousands(required)
		var short := held < required
		var sb := MedievalTheme.flat(
			MedievalTheme.SHORT_BG if short else MedievalTheme.VELLUM,
			MedievalTheme.BLOOD if short else MedievalTheme.OAK_EDGE, 3, 1, 8, 8)
		chip.add_theme_stylebox_override("panel", sb)
		_cost_labels[r].add_theme_color_override("font_color", MedievalTheme.BLOOD if short else MedievalTheme.INK)
	cost_section.show()


## Pokazuje sekcję licznika i odlicza w _process; ULEPSZ wyłączone, dopóki trwa budowa.
func refresh_timer(remaining: float, total: float) -> void:
	_remaining = maxf(remaining, 0.0)
	_total = maxf(total, 0.001)
	timer_section.show()
	_apply_timer()
	set_process(_remaining > 0.0)


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	_apply_timer()
	if is_zero_approx(_remaining):
		set_process(false)


func _apply_timer() -> void:
	var s := int(_remaining)
	@warning_ignore("integer_division")
	timer_label.text = "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	construction_bar.value = 1.0 - _remaining / _total
	upgrade_button.disabled = _remaining > 0.0


func _on_upgrade() -> void:
	if _settlement != null and _building >= 0:
		upgrade_requested.emit(_settlement.coord, _building)
	close_requested.emit()
```

- [ ] **Step 5: `scenes/ui/SheetStyle.gd`** (wspólne style arkuszy; mały plik, żeby trzy arkusze nie powielały kodu)

```gdscript
class_name SheetStyle
extends RefCounted

## Wspólne ustawienia arkuszy od dołu: margines, uchwyt, separacja.

const MARGIN := 14.0
const GRABBER := Vector2(44.0, 4.0)


static func apply_common(sheet: PanelContainer, grabber: Panel) -> void:
	var margin: MarginContainer = sheet.get_node("SheetMargin")
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MedievalTheme.px(MARGIN))
	(margin.get_child(0) as Control).add_theme_constant_override("separation", MedievalTheme.px(11))
	grabber.custom_minimum_size = Vector2(MedievalTheme.px(GRABBER.x), MedievalTheme.px(GRABBER.y))
	grabber.add_theme_stylebox_override("panel", MedievalTheme.flat(MedievalTheme.OAK_EDGE, MedievalTheme.OAK_EDGE, 2, 0, 0, 0))
```

- [ ] **Step 6: `scenes/ui/Sheets.tscn`** (na razie tylko arkusz budynku; Task 9 i 10 dopiszą kolejne)

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/ui/Sheets.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/BuildingSheet.tscn" id="2"]

[node name="Sheets" type="CanvasLayer" groups=["sheets"]]
layer = 12
visible = false
script = ExtResource("1")

[node name="Backdrop" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
color = Color(0.08, 0.04, 0, 0.55)

[node name="BuildingSheet" parent="." instance=ExtResource("2")]
```

- [ ] **Step 7: `scenes/ui/Sheets.gd`**

```gdscript
extends CanvasLayer

## Zarządca arkuszy od dołu: backdrop, co najwyżej jeden otwarty arkusz, animacje otwarcia
## i zamknięcia, zamykanie przy zmianie widoku. Widoki wołają open_*(), reszta chrome nie.

signal upgrade_requested(coord: Vector2i, building: int)

const FADE_TIME := 0.18
const SLIDE_TIME := 0.26
const HEIGHT_FLEETS := 0.66
const HEIGHT_INSPECT := 0.34
const HEIGHT_BUILDING := 0.5

@onready var backdrop: ColorRect = $Backdrop
@onready var building_sheet: BuildingSheet = $BuildingSheet

var _current: Control = null
var _current_fraction := 0.0
var _tween: Tween = null


func _ready() -> void:
	visible = false
	backdrop.gui_input.connect(_on_backdrop_input)
	for s in _all_sheets():
		s.hide()
		s.close_requested.connect(close)
	building_sheet.upgrade_requested.connect(_on_upgrade_requested)
	SceneManager.view_changed.connect(func(_path: String) -> void: _hide_now())
	get_viewport().size_changed.connect(_relayout)


func _all_sheets() -> Array:
	var out: Array = []
	for c in get_children():
		if c != backdrop and c is PanelContainer:
			out.append(c)
	return out


func is_open() -> bool:
	return _current != null


func current_sheet() -> Control:
	return _current


func open_fleets() -> void:
	var sheet := get_node_or_null("FleetsSheet")
	if sheet == null:
		push_warning("Sheets: FleetsSheet jeszcze nie istnieje")
		return
	sheet.refresh()
	_open(sheet, HEIGHT_FLEETS)


func open_inspect(coord: Vector2i) -> bool:
	var sheet := get_node_or_null("InspectSheet")
	if sheet == null:
		push_warning("Sheets: InspectSheet jeszcze nie istnieje")
		return false
	if not sheet.open(coord):
		return false
	_open(sheet, HEIGHT_INSPECT)
	return true


func open_building(settlement: Settlement, building: int) -> bool:
	if not building_sheet.open(settlement, building):
		return false
	_open(building_sheet, HEIGHT_BUILDING)
	return true


func close() -> void:
	if _current == null:
		return
	var panel := _current
	_current = null
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(backdrop, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_property(panel, "position:y", panel.position.y + panel.size.y, SLIDE_TIME)
	_tween.chain().tween_callback(func() -> void:
		panel.hide()
		if _current == null:
			visible = false
	)


func _open(panel: Control, fraction: float) -> void:
	_kill_tween()
	for s in _all_sheets():
		if s != panel:
			s.hide()
	_current = panel
	_current_fraction = fraction
	_layout(panel, fraction)
	visible = true
	panel.show()
	backdrop.modulate.a = 0.0
	var rest := panel.position.y
	panel.position.y = rest + panel.size.y
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(backdrop, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_property(panel, "position:y", rest, SLIDE_TIME)


## Bez animacji: zmiana widoku albo otwarcie innego arkusza przy otwartym.
func _hide_now() -> void:
	_kill_tween()
	for s in _all_sheets():
		s.hide()
	_current = null
	visible = false
	backdrop.modulate.a = 1.0


## Arkusz zajmuje ułamek wysokości viewportu, przypięty do dołu na całą szerokość.
func _layout(panel: Control, fraction: float) -> void:
	var vis := get_viewport().get_visible_rect().size
	var h := roundf(vis.y * fraction)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = -h
	panel.offset_bottom = 0.0


func _relayout() -> void:
	if _current != null:
		_layout(_current, _current_fraction)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null


func _on_backdrop_input(event: InputEvent) -> void:
	var touch := event is InputEventScreenTouch and event.pressed
	var click := event is InputEventMouseButton and event.pressed
	if touch or click:
		close()


func _on_upgrade_requested(coord: Vector2i, building: int) -> void:
	upgrade_requested.emit(coord, building)
```

- [ ] **Step 8: `scenes/views/IslandDetail.tscn`** (całość)

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/views/IslandDetail.gd" id="1"]
[ext_resource type="Script" path="res://scenes/procedural/IslandGenerator.gd" id="2"]

[node name="IslandDetail" type="Node2D"]
script = ExtResource("1")

[node name="Generator" type="Node2D" parent="."]
script = ExtResource("2")

[node name="Camera" type="Camera2D" parent="."]
current = true

[node name="UI" type="CanvasLayer" parent="."]
layer = 1

[node name="HintPanel" type="PanelContainer" parent="UI"]
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
grow_vertical = 0
mouse_filter = 2
theme_type_variation = &"Plaque"

[node name="Hint" type="Label" parent="UI/HintPanel"]
layout_mode = 2
text = "Dotknij slotu, żeby otworzyć budynek"
```

- [ ] **Step 9: `scenes/views/IslandDetail.gd`** (całość)

```gdscript
extends Node2D

## Dom gracza: osada aktywna z plakietkami slotów. Cudze i niczyje wyspy obsługuje InspectSheet
## nad mapą, nie ten widok. Tap w slot otwiera BuildingSheet przez grupę "sheets".

const DETAIL_RADIUS := 400.0
## Wysokość przycisku docku plus margines (w px projektu), żeby wyspa nie chowała się pod nim.
const DOCK_CLEARANCE := 46.0 + 24.0
const HINT_MARGIN := 10.0
const HINT_TEXT := "Dotknij slotu, żeby otworzyć budynek"
const NO_SETTLEMENT_TEXT := "Brak osady"

@onready var generator: IslandGenerator = $Generator
@onready var camera: Camera2D = $Camera
@onready var hint_panel: PanelContainer = $UI/HintPanel
@onready var hint_label: Label = $UI/HintPanel/Hint

var _settlement: Settlement = null
var _pressed_slot: int = -1
var _hint_dismissed := false


func _ready() -> void:
	GameState.active_settlement_changed.connect(_refresh)
	GameState.settlement_updated.connect(_on_settlement_updated)
	get_viewport().size_changed.connect(_layout)
	_refresh()
	_layout()


func _refresh() -> void:
	_settlement = GameState.active_settlement
	_pressed_slot = -1
	if _settlement == null:
		generator.clear()
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
	hint_label.text = HINT_TEXT
	hint_panel.visible = not _hint_dismissed


func _on_settlement_updated(coord: Vector2i) -> void:
	if _settlement != null and coord == _settlement.coord:
		_refresh()


## Wyspa w środku obszaru między dołem paska HUD a górą docku.
func _layout() -> void:
	var vis := get_viewport().get_visible_rect().size
	var top := _hud_bar_height()
	var bottom := vis.y - SafeArea.bottom_inset(get_viewport()) - MedievalTheme.px(DOCK_CLEARANCE)
	var mid := (top + bottom) / 2.0
	camera.position = Vector2(0.0, vis.y / 2.0 - mid)
	hint_panel.offset_left = MedievalTheme.px(HINT_MARGIN)
	hint_panel.offset_bottom = -(vis.y - bottom)


func _hud_bar_height() -> float:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud.bar_height() if hud != null else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _settlement == null or not generator.show_slots:
		return
	if event is InputEventScreenTouch:
		var slot := _slot_under(event.position)
		if event.pressed:
			_pressed_slot = slot
			if slot >= 0:
				generator.set_pressed(slot, true)
		else:
			if _pressed_slot >= 0:
				generator.set_pressed(_pressed_slot, false)
			if slot >= 0 and slot == _pressed_slot:
				_open_building(slot)
			_pressed_slot = -1
	elif event is InputEventScreenDrag and _pressed_slot >= 0:
		if _slot_under(event.position) != _pressed_slot:
			generator.set_pressed(_pressed_slot, false)
			_pressed_slot = -1


func _slot_under(screen_pos: Vector2) -> int:
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	return generator.slot_at(generator.to_local(world_pos))


func _open_building(slot: int) -> void:
	var sheets := get_tree().get_first_node_in_group("sheets")
	if sheets == null:
		push_warning("IslandDetail: brak węzła w grupie sheets")
		return
	if sheets.open_building(_settlement, slot):
		_hint_dismissed = true
		hint_panel.hide()
```

- [ ] **Step 10: `Main.tscn` i `Main.gd`**

Do `Main.tscn` dodaj zasób i instancję (po `HUD`):

```
[ext_resource type="PackedScene" path="res://scenes/ui/Sheets.tscn" id="3"]
...
[node name="Sheets" parent="." instance=ExtResource("3")]
```

(zwiększ `load_steps` do 4). W `Main.gd` dodaj `@onready var sheets: CanvasLayer = $Sheets` i w `_ready()` przed `load_initial()`:

```gdscript
	sheets.upgrade_requested.connect(func(coord: Vector2i, building: int) -> void:
		print("upgrade_requested: %s w %s" % [Buildings.key(building), Coord.key(coord)])
	)
```

- [ ] **Step 11: Usuń `BuildingMenu`**

```bash
git rm scenes/ui/BuildingMenu.tscn scenes/ui/BuildingMenu.gd scenes/ui/BuildingMenu.gd.uid
grep -rn "BuildingMenu" scenes scripts test tools || echo "brak odwołań"
```

Oczekiwane: `brak odwołań`.

- [ ] **Step 12: Tymczasowy smoke** (`tools/smoke_probe.gd`, klatki od `39` w dół; pełny nowy przepływ przyjdzie w Task 11)

Zamień blok od `39:` do końca `_process` na:

```gdscript
		39:
			_check(
				SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL,
				"kliknięcie w wyspę otwiera widok osady"
			)
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			var gen: IslandGenerator = det.get_node("Generator") if det != null else null
			_check(det != null and gen.show_slots, "własna osada ma sloty")
			_check(det != null and gen._slot_positions.size() == 6, "6 slotów")
			if det != null and gen.show_slots:
				var at := _viewport_to_window(_slot_viewport_point(det, gen, Buildings.Type.TOWN_HALL))
				_mouse_press(at)
				_mouse_release(at)
		41:
			var sheets := get_node("Main/Sheets")
			_check(sheets.is_open() and sheets.building_sheet.visible, "tapnięcie w slot otwiera arkusz budynku")
			_check(sheets.building_sheet.name_label.text == "Ratusz", "arkusz pokazuje ratusz")
			sheets.close()
		44:
			var hud := get_node("Main/HUD")
			_check(hud.settlement_name.text == "Koralowa", "HUD pokazuje osadę aktywną")
			_check(hud.pop_label.text == "42 / 120", "HUD pokazuje populację")
			ApiClient.resync()
		49:
			_check(GameState.settlements.size() == 3, "resync zachowuje osady")
			SceneManager.show_world_map()
		54:
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "powrót na mapę")
			print("SMOKE %s" % ("FAILED" if _failed else "PASSED"))
			get_tree().quit(1 if _failed else 0)
```

Usuń z probe'a zmienne i komentarze o `BuildingMenu`, `InfoPanel` i `BackButton`.

- [ ] **Step 13: Uruchom testy i smoke**

```bash
./run_tests.sh test/scenes
./run_smoke.sh
```

Oczekiwane: zielono, `SMOKE PASSED`. Typowe potknięcia: `SheetStyle.apply_common` zakłada, że pierwsze dziecko `SheetMargin` to `VBoxContainer` (tak jest w scenie); `assert_error(...).is_push_error` wymaga dokładnie tego samego tekstu co w `push_error`.

- [ ] **Step 14: Commit**

```bash
git add scenes/ui/Sheets.tscn scenes/ui/Sheets.gd scenes/ui/Sheets.gd.uid scenes/ui/SheetStyle.gd scenes/ui/SheetStyle.gd.uid scenes/ui/BuildingSheet.tscn scenes/ui/BuildingSheet.gd scenes/ui/BuildingSheet.gd.uid scenes/views/IslandDetail.tscn scenes/views/IslandDetail.gd scenes/views/Main.tscn scenes/views/Main.gd tools/smoke_probe.gd test/scenes/sheets_test.gd test/scenes/sheets_test.gd.uid test/scenes/building_sheet_test.gd test/scenes/building_sheet_test.gd.uid
git commit -m "Add bottom sheets with BuildingSheet; settlement view shows only the active settlement"
```

---

### Task 9: Warstwa UI mapy i `InspectSheet`

**Files:**
- Create: `scenes/ui/InspectSheet.tscn`, `scenes/ui/InspectSheet.gd`
- Modify: `scenes/views/WorldMap.tscn` (warstwa `UI`), `scenes/views/WorldMap.gd` (kolory, `_process`, `_layout_ui`, `_on_tapped`), `scenes/views/Water.gd:5`, `scenes/ui/Sheets.tscn` (instancja `InspectSheet`), `scenes/ui/Sheets.gd` (pole `inspect_sheet`)
- Test: `test/scenes/inspect_sheet_test.gd`, `test/scenes/sheets_test.gd`, `test/scenes/world_map_test.gd`

**Interfaces:**
- Consumes: `Sheets.open_inspect`, `GameState.island_at`, `settlement_at`, `inspect`, `Island.has_deposit()`, `Island.deposit`, `HUD.bar_height()`.
- Produces: `InspectSheet` (`PanelContainer`) z `open(coord: Vector2i) -> bool`, sygnał `close_requested`, pola `name_label`, `biome_badge`, `subtitle`, `public_label`, `deposit_header`, `deposit_row`, `empty_label`. `WorldMap` pola `back_plaque`, `coord_label`, `zoom_in`, `zoom_out`; stałe `OWN_COLOR = MedievalTheme.BRASS`, `FOREIGN_COLOR = MedievalTheme.CREAM_SOFT`.

- [ ] **Step 1: Testy**

`test/scenes/inspect_sheet_test.gd`:

```gdscript
extends GdUnitTestSuite

const SHEET := preload("res://scenes/ui/InspectSheet.tscn")
## Dla ziarna 1337: (95, 100) ląd z cudzą osadą w fixtures, (95, 98) ląd ze znaleziskiem,
## (100, 100) morze (patrz game_state_test.gd i smoke_probe.gd).
const FOREIGN := Vector2i(95, 100)
const EMPTY_WITH_DEPOSIT := Vector2i(95, 98)
const SEA := Vector2i(100, 100)


func before_test() -> void:
	GameState.reset()
	GameState.apply_world({
		"id": "w1", "seed": 1337, "size": {"w": 200, "h": 200},
		"playerId": 7, "homeSettlement": {"x": 103, "y": 100},
	})
	GameState.apply_settlements([{"x": FOREIGN.x, "y": FOREIGN.y, "ownerId": 9, "name": "Szara Skała"}])


func after_test() -> void:
	GameState.reset()


func _sheet() -> InspectSheet:
	var s: InspectSheet = auto_free(SHEET.instantiate())
	add_child(s)
	return s


func test_foreign_settlement_shows_public_data() -> void:
	var s := _sheet()
	assert_bool(s.open(FOREIGN)).is_true()
	assert_str(s.name_label.text).is_equal("Szara Skała")
	assert_str(s.subtitle.text).is_equal("(95, 100) · gracz 9")
	assert_str(s.biome_badge.text).is_equal(Biome.key(GameState.island_at(FOREIGN).biome))
	assert_bool(s.public_label.visible).is_true()
	assert_bool(s.deposit_header.visible).is_false()
	assert_bool(s.empty_label.visible).is_false()


func test_unowned_island_with_deposit_lists_chips() -> void:
	var island := GameState.island_at(EMPTY_WITH_DEPOSIT)
	assert_object(island).is_not_null()
	assert_bool(island.has_deposit()).is_true()
	var s := _sheet()
	assert_bool(s.open(EMPTY_WITH_DEPOSIT)).is_true()
	assert_str(s.name_label.text).is_equal("Wyspa (95, 98)")
	assert_str(s.subtitle.text).is_equal("(95, 98) · wyspa niczyja")
	assert_bool(s.deposit_header.visible).is_true()
	assert_int(s.deposit_row.get_child_count()).is_equal(island.deposit.size())
	assert_bool(s.public_label.visible).is_false()


func test_sea_is_rejected() -> void:
	var s := _sheet()
	await assert_error(func() -> void: s.open(SEA)).is_push_error("InspectSheet: (100, 100) nie jest wyspą")
```

Dopisz do `test/scenes/sheets_test.gd`:

```gdscript
func test_open_inspect_on_sea_keeps_layer_closed() -> void:
	var s := _sheets()
	GameState.apply_world({
		"id": "w1", "seed": 1337, "size": {"w": 200, "h": 200},
		"playerId": 7, "homeSettlement": {"x": 103, "y": 100},
	})
	await assert_error(func() -> void: s.open_inspect(Vector2i(100, 100))) \
		.is_push_error("InspectSheet: (100, 100) nie jest wyspą")
	assert_bool(s.is_open()).is_false()


func test_open_inspect_replaces_open_building_sheet() -> void:
	var s := _sheets()
	GameState.apply_world({
		"id": "w1", "seed": 1337, "size": {"w": 200, "h": 200},
		"playerId": 7, "homeSettlement": {"x": 103, "y": 100},
	})
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	assert_bool(s.open_inspect(Vector2i(95, 98))).is_true()
	assert_object(s.current_sheet()).is_same(s.inspect_sheet)
	assert_bool(s.building_sheet.visible).is_false()
	assert_bool(s.inspect_sheet.visible).is_true()
```

Dopisz do `test/scenes/world_map_test.gd`:

```gdscript
func test_ui_layer_exists_with_back_and_zoom_buttons() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	assert_object(world_map.back_plaque).is_instanceof(Button)
	assert_object(world_map.zoom_in).is_instanceof(Button)
	assert_object(world_map.zoom_out).is_instanceof(Button)
	var before: float = (world_map.camera as MapCamera).zoom.x
	world_map.zoom_in.pressed.emit()
	assert_float((world_map.camera as MapCamera).zoom.x).is_greater(before)


func test_coord_panel_follows_camera() -> void:
	_apply_world()
	var world_map := _spawn_map(WorldGrid.cell_to_world(HOME_CELL))
	await _settle(world_map)
	world_map._process(0.0)
	assert_str(world_map.coord_label.text).is_equal("X 103 · Y 100 · zoom 1.0")
```

- [ ] **Step 2: Uruchom, oczekuj błędów**

```bash
./run_tests.sh test/scenes/inspect_sheet_test.gd
./run_tests.sh test/scenes/world_map_test.gd
```

- [ ] **Step 3: `scenes/ui/InspectSheet.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/ui/InspectSheet.gd" id="1"]
[ext_resource type="Script" path="res://scenes/ui/Icon.gd" id="2"]

[node name="InspectSheet" type="PanelContainer"]
visible = false
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 0
mouse_filter = 0
theme_type_variation = &"Sheet"
script = ExtResource("1")

[node name="SheetMargin" type="MarginContainer" parent="."]
layout_mode = 2
mouse_filter = 2

[node name="Body" type="VBoxContainer" parent="SheetMargin"]
layout_mode = 2
mouse_filter = 2

[node name="Grabber" type="Panel" parent="SheetMargin/Body"]
layout_mode = 2
size_flags_horizontal = 4
mouse_filter = 2

[node name="Header" type="PanelContainer" parent="SheetMargin/Body"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"ModalHeader"

[node name="HBox" type="HBoxContainer" parent="SheetMargin/Body/Header"]
layout_mode = 2
mouse_filter = 2

[node name="BiomeIcon" type="Control" parent="SheetMargin/Body/Header/HBox"]
layout_mode = 2
script = ExtResource("2")

[node name="Name" type="Label" parent="SheetMargin/Body/Header/HBox"]
layout_mode = 2
size_flags_horizontal = 3
clip_text = true
theme_type_variation = &"Title"

[node name="BiomeBadge" type="Label" parent="SheetMargin/Body/Header/HBox"]
layout_mode = 2
size_flags_vertical = 4
theme_type_variation = &"Badge"

[node name="CloseButton" type="Button" parent="SheetMargin/Body/Header/HBox"]
layout_mode = 2
size_flags_vertical = 4
theme_type_variation = &"ToolButton"

[node name="Subtitle" type="Label" parent="SheetMargin/Body"]
layout_mode = 2
theme_type_variation = &"Caption"

[node name="PublicLabel" type="Label" parent="SheetMargin/Body"]
layout_mode = 2
text = "Dane publiczne: nazwa i właściciel."
autowrap_mode = 3

[node name="DepositHeader" type="Label" parent="SheetMargin/Body"]
layout_mode = 2
text = "ZNALEZISKO"
theme_type_variation = &"SectionHeader"

[node name="DepositRow" type="HBoxContainer" parent="SheetMargin/Body"]
layout_mode = 2
mouse_filter = 2

[node name="EmptyLabel" type="Label" parent="SheetMargin/Body"]
layout_mode = 2
text = "Brak znaleziska."
```

Uwaga: `Subtitle` w wariacji `Caption` ma kolor `CREAM_SOFT`; na pergaminie skrypt nadpisuje go na `INK_SOFT`.

- [ ] **Step 4: `scenes/ui/InspectSheet.gd`**

```gdscript
class_name InspectSheet
extends PanelContainer

## Arkusz oglądanej wyspy nad mapą: cudza osada (dane publiczne) albo wyspa niczyja (znalezisko).

signal close_requested

const ICON := 40.0
const CLOSE := 30.0
const CHIP_ICON := 13.0

@onready var grabber: Panel = $SheetMargin/Body/Grabber
@onready var biome_icon: Icon = $SheetMargin/Body/Header/HBox/BiomeIcon
@onready var name_label: Label = $SheetMargin/Body/Header/HBox/Name
@onready var biome_badge: Label = $SheetMargin/Body/Header/HBox/BiomeBadge
@onready var close_button: Button = $SheetMargin/Body/Header/HBox/CloseButton
@onready var subtitle: Label = $SheetMargin/Body/Subtitle
@onready var public_label: Label = $SheetMargin/Body/PublicLabel
@onready var deposit_header: Label = $SheetMargin/Body/DepositHeader
@onready var deposit_row: HBoxContainer = $SheetMargin/Body/DepositRow
@onready var empty_label: Label = $SheetMargin/Body/EmptyLabel


func _ready() -> void:
	SheetStyle.apply_common(self, grabber)
	biome_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
	biome_icon.color = MedievalTheme.CREAM
	close_button.custom_minimum_size = Vector2.ONE * MedievalTheme.px(CLOSE)
	Icon.into_button(close_button, &"close", MedievalTheme.CREAM, MedievalTheme.px(7))
	subtitle.add_theme_color_override("font_color", MedievalTheme.INK_SOFT)
	close_button.pressed.connect(func() -> void: close_requested.emit())


## Zwraca false (i push_error) dla komórki bez wyspy.
func open(coord: Vector2i) -> bool:
	var island := GameState.island_at(coord)
	if island == null:
		push_error("InspectSheet: %s nie jest wyspą" % coord)
		return false
	var s := GameState.settlement_at(coord)
	biome_icon.kind = ResourceTypes.ICONS[Biome.resources(island.biome)[0]]
	biome_badge.text = Biome.key(island.biome)
	for c in deposit_row.get_children():
		c.queue_free()
	if s != null:
		name_label.text = s.name
		subtitle.text = "(%d, %d) · gracz %d" % [coord.x, coord.y, s.owner_id]
		public_label.show()
		deposit_header.hide()
		deposit_row.hide()
		empty_label.hide()
		return true
	name_label.text = "Wyspa (%d, %d)" % [coord.x, coord.y]
	subtitle.text = "(%d, %d) · wyspa niczyja" % [coord.x, coord.y]
	public_label.hide()
	if island.has_deposit():
		for r in island.deposit:
			deposit_row.add_child(_chip(r, float(island.deposit[r])))
		deposit_header.show()
		deposit_row.show()
		empty_label.hide()
	else:
		deposit_header.hide()
		deposit_row.hide()
		empty_label.show()
	return true


func _chip(resource: String, amount: float) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Icon.new()
	icon.kind = ResourceTypes.ICONS[resource]
	icon.color = ResourceTypes.COLORS[resource]
	icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(CHIP_ICON)
	var label := Label.new()
	label.theme_type_variation = &"Amount"
	label.add_theme_color_override("font_color", MedievalTheme.CREAM)
	label.text = "%s %s" % [TimeUtil.format_thousands(amount), ResourceTypes.LABELS[resource].to_lower()]
	box.add_child(icon)
	box.add_child(label)
	chip.add_child(box)
	return chip
```

- [ ] **Step 5: Podepnij `InspectSheet` do `Sheets`**

W `Sheets.tscn` dodaj `[ext_resource type="PackedScene" path="res://scenes/ui/InspectSheet.tscn" id="3"]`, zwiększ `load_steps` do 4 i dodaj po `Backdrop`: `[node name="InspectSheet" parent="." instance=ExtResource("3")]`. W `Sheets.gd` dodaj `@onready var inspect_sheet: InspectSheet = $InspectSheet` i uprość `open_inspect`:

```gdscript
func open_inspect(coord: Vector2i) -> bool:
	if not inspect_sheet.open(coord):
		return false
	_open(inspect_sheet, HEIGHT_INSPECT)
	return true
```

- [ ] **Step 6: `scenes/views/WorldMap.tscn`**: dodaj warstwę UI (po `Camera`)

Ikony powstają w kodzie, więc tscn nie potrzebuje nowych zasobów. Dodaj węzły:

```
[node name="UI" type="CanvasLayer" parent="."]
layer = 1

[node name="BackPlaque" type="Button" parent="UI"]
text = "OSADA"
alignment = 2
theme_type_variation = &"ToolButton"

[node name="CoordPanel" type="PanelContainer" parent="UI"]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
grow_horizontal = 0
mouse_filter = 2
theme_type_variation = &"Chip"

[node name="Coord" type="Label" parent="UI/CoordPanel"]
layout_mode = 2
theme_type_variation = &"Caption"

[node name="ZoomControls" type="VBoxContainer" parent="UI"]
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 0
grow_vertical = 0
mouse_filter = 2

[node name="ZoomIn" type="Button" parent="UI/ZoomControls"]
layout_mode = 2
theme_type_variation = &"ToolButton"

[node name="ZoomOut" type="Button" parent="UI/ZoomControls"]
layout_mode = 2
theme_type_variation = &"ToolButton"
```

- [ ] **Step 7: `scenes/views/WorldMap.gd`**: kolory, UI, tap

Zamień stałe kolorów:

```gdscript
const OWN_COLOR := MedievalTheme.BRASS
const FOREIGN_COLOR := MedievalTheme.CREAM_SOFT
const LABEL_FONT_SIZE := 32
const UI_MARGIN := 10.0
const TOOL := 46.0
const BACK_WIDTH := 110.0
```

Dodaj `@onready`:

```gdscript
@onready var back_plaque: Button = $UI/BackPlaque
@onready var coord_panel: PanelContainer = $UI/CoordPanel
@onready var coord_label: Label = $UI/CoordPanel/Coord
@onready var zoom_controls: VBoxContainer = $UI/ZoomControls
@onready var zoom_in: Button = $UI/ZoomControls/ZoomIn
@onready var zoom_out: Button = $UI/ZoomControls/ZoomOut
```

Na końcu `_ready()` dopisz:

```gdscript
	back_plaque.pressed.connect(SceneManager.show_island_detail)
	zoom_in.pressed.connect(camera.zoom_by.bind(1.25))
	zoom_out.pressed.connect(camera.zoom_by.bind(0.8))
	_style_ui()
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
```

W `_process` dopisz na końcu:

```gdscript
	var cell := WorldGrid.world_to_cell(camera.position)
	coord_label.text = "X %d · Y %d · zoom %.1f" % [cell.x, cell.y, camera.zoom.x]
```

Nowe metody:

```gdscript
func _style_ui() -> void:
	var tool := MedievalTheme.px(TOOL)
	back_plaque.custom_minimum_size = Vector2(MedievalTheme.px(BACK_WIDTH), tool)
	Icon.into_button(back_plaque, &"back", MedievalTheme.CREAM, MedievalTheme.px(12))
	var back_icon: Icon = back_plaque.get_node("Icon")
	back_icon.set_anchors_preset(Control.PRESET_LEFT_WIDE)   # zeruje offsety, stąd ustawiane poniżej
	back_icon.offset_left = MedievalTheme.px(12)
	back_icon.offset_right = MedievalTheme.px(12 + 22)
	back_icon.offset_top = MedievalTheme.px(12)
	back_icon.offset_bottom = -MedievalTheme.px(12)
	coord_label.add_theme_color_override("font_color", MedievalTheme.PARCHMENT)
	zoom_controls.add_theme_constant_override("separation", MedievalTheme.px(8))
	for b in [zoom_in, zoom_out]:
		b.custom_minimum_size = Vector2(tool, tool)
	Icon.into_button(zoom_in, &"plus", MedievalTheme.CREAM, MedievalTheme.px(13))
	Icon.into_button(zoom_out, &"minus", MedievalTheme.CREAM, MedievalTheme.px(13))


## Plakietka powrotu i panel współrzędnych pod paskiem HUD, zoom nad safe area.
func _layout_ui() -> void:
	var m := MedievalTheme.px(UI_MARGIN)
	var hud := get_tree().get_first_node_in_group("hud")
	var top: float = (hud.bar_height() if hud != null else 0.0) + m
	back_plaque.position = Vector2(m, top)
	coord_panel.offset_top = top
	coord_panel.offset_right = -m
	zoom_controls.offset_right = -m
	zoom_controls.offset_bottom = -(SafeArea.bottom_inset(get_viewport()) + m)
```

W `_rebuild_labels` zamień stylowanie etykiety na:

```gdscript
		label.theme_type_variation = &"Title"
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		label.add_theme_color_override("font_color", OWN_COLOR if s.is_own else FOREIGN_COLOR)
```

(usuń `label.modulate = ...`). Zamień końcówkę `_on_tapped`:

```gdscript
	var s := GameState.settlement_at(cell)
	if s != null and s.is_own:
		GameState.set_active_settlement(cell)
		SceneManager.show_island_detail()
		return
	GameState.inspect(cell)
	var sheets := get_tree().get_first_node_in_group("sheets")
	if sheets != null:
		sheets.open_inspect(cell)
```

W `scenes/views/Water.gd` zamień `LINE_COLOR` na `const LINE_COLOR := Color(0.0, 0.0, 0.0, 0.18)` (ciemniejszy odcień morza; `MedievalTheme.SEA.darkened(0.25)` nie może być stałą, a półprzezroczysta czerń daje ten sam efekt na każdym tle).

- [ ] **Step 8: Uruchom testy i smoke**

```bash
./run_tests.sh test/scenes
./run_smoke.sh
```

Oczekiwane: zielono. W tymczasowym smoke tap w (103, 100) dalej otwiera widok osady (własna osada), więc przepływ się nie zmienia.

- [ ] **Step 9: Commit**

```bash
git add scenes/ui/InspectSheet.tscn scenes/ui/InspectSheet.gd scenes/ui/InspectSheet.gd.uid scenes/ui/Sheets.tscn scenes/ui/Sheets.gd scenes/views/WorldMap.tscn scenes/views/WorldMap.gd scenes/views/Water.gd test/scenes/inspect_sheet_test.gd test/scenes/inspect_sheet_test.gd.uid test/scenes/sheets_test.gd test/scenes/world_map_test.gd
git commit -m "Add map UI layer (back, coords, zoom) and InspectSheet for foreign and unowned islands"
```

---

### Task 10: `Dock`, `FleetCard`, `FleetsSheet`

**Files:**
- Create: `scenes/ui/Dock.tscn`, `scenes/ui/Dock.gd`, `scenes/ui/FleetCard.tscn`, `scenes/ui/FleetCard.gd`, `scenes/ui/FleetsSheet.tscn`, `scenes/ui/FleetsSheet.gd`
- Modify: `scenes/ui/Sheets.tscn`, `scenes/ui/Sheets.gd`, `scenes/views/Main.tscn`
- Test: `test/scenes/fleet_card_test.gd`, `test/scenes/fleets_sheet_test.gd`, `test/scenes/dock_test.gd`, `test/scenes/sheets_test.gd`

**Interfaces:**
- Consumes: `Fleet.MISSION_LABELS/ICONS`, `TimeUtil.format_eta`, `SceneManager.show_world_map_at`, `GameState.fleets`, `GameState.player_id`.
- Produces: `FleetCard` (`PanelContainer`) z `var fleet: Fleet`, `refresh(fleet: Fleet, now: float, player_id: int)`, sygnał `tapped(fleet: Fleet)`, pola `title`, `eta_label`, `eta_bar`, `composition`, `mission_icon`. `FleetsSheet` z `refresh()`, sygnały `fleet_tapped(fleet)`, `close_requested`, pola `list`, `incoming_header`, `own_header`, `empty_label`, `func cards() -> Array`. `Dock` (`CanvasLayer`) z polami `fleets_button`, `map_button`, `badge`, `func refresh_badge()`. `Sheets.fleets_sheet`.

- [ ] **Step 1: Testy**

`test/scenes/fleet_card_test.gd`:

```gdscript
extends GdUnitTestSuite

const CARD := preload("res://scenes/ui/FleetCard.tscn")
const DEPART := 1788782400.0
const ARRIVE := DEPART + 3600.0


func _fleet(mission: String, owner: int) -> Fleet:
	return Fleet.from_json({
		"id": "f1", "ownerId": owner, "mission": mission,
		"from": {"x": 0, "y": 0}, "to": {"x": 4, "y": 0},
		"ships": {"SLOOP": 10, "GALLEON": 2},
		"cargo": {"units": {"MILITIA": 20}, "resources": {"iron": 300}},
		"departAt": TimeUtil.to_iso8601(DEPART), "arriveAt": TimeUtil.to_iso8601(ARRIVE),
	})


func _card() -> FleetCard:
	var c: FleetCard = auto_free(CARD.instantiate())
	add_child(c)
	return c


func test_own_fleet_shows_title_eta_and_composition() -> void:
	var c := _card()
	c.refresh(_fleet("EXPEDITION", 7), DEPART + 1800.0, 7)
	assert_str(c.title.text).is_equal("Wyprawa → (4, 0)")
	assert_str(c.eta_label.text).is_equal("30:00")
	assert_float(c.eta_bar.value).is_equal_approx(0.5, 0.001)
	assert_str(c.composition.text).is_equal("10 × slup · 2 × galeon · 20 × MILITIA · 300 żelazo")
	assert_str(String(c.eta_bar.theme_type_variation)).is_equal("ScoutBar")
	assert_that((c.get_theme_stylebox("panel") as StyleBoxFlat).border_color).is_equal(MedievalTheme.MOSS)


func test_foreign_attack_hides_details_and_is_red() -> void:
	var c := _card()
	c.refresh(_fleet("ATTACK", 9), DEPART, 7)
	assert_str(c.title.text).is_equal("Atak → (4, 0)")
	assert_str(c.composition.text).is_equal("gracz 9 · szczegóły niewidoczne")
	assert_str(String(c.eta_bar.theme_type_variation)).is_equal("RaidBar")
	assert_that((c.get_theme_stylebox("panel") as StyleBoxFlat).border_color).is_equal(MedievalTheme.BLOOD)
	assert_str(String(c.mission_icon.kind)).is_equal("raid")


func test_arrived_fleet_is_full_and_zero_eta() -> void:
	var c := _card()
	c.refresh(_fleet("TRANSPORT", 7), ARRIVE + 10.0, 7)
	assert_float(c.eta_bar.value).is_equal(1.0)
	assert_str(c.eta_label.text).is_equal("00:00")
	assert_that((c.get_theme_stylebox("panel") as StyleBoxFlat).border_color).is_equal(MedievalTheme.BRASS)


func test_unknown_mission_falls_back() -> void:
	var c := _card()
	c.refresh(_fleet("PATROL", 7), DEPART, 7)
	assert_str(c.title.text).is_equal("PATROL → (4, 0)")
	assert_str(String(c.mission_icon.kind)).is_equal("fleet")


func test_touch_release_emits_tapped() -> void:
	var c := _card()
	var f := _fleet("TRANSPORT", 7)
	c.refresh(f, DEPART, 7)
	var got: Array = []
	c.tapped.connect(func(x: Fleet) -> void: got.append(x))
	var touch := InputEventScreenTouch.new()
	touch.pressed = false
	c.gui_input.emit(touch)
	assert_that(got).is_equal([f])
```

`test/scenes/fleets_sheet_test.gd`:

```gdscript
extends GdUnitTestSuite

const SHEET := preload("res://scenes/ui/FleetsSheet.tscn")


func before_test() -> void:
	GameState.reset()
	GameState.apply_world({
		"id": "w1", "seed": 1337, "size": {"w": 200, "h": 200},
		"playerId": 7, "homeSettlement": {"x": 103, "y": 100},
	})


func after_test() -> void:
	GameState.reset()


func _fleet(id: String, owner: int, arrive_in: float) -> Dictionary:
	var now := TimeUtil.now()
	return {
		"id": id, "ownerId": owner, "mission": "TRANSPORT",
		"from": {"x": 0, "y": 0}, "to": {"x": 4, "y": 0}, "ships": {"SLOOP": 1},
		"departAt": TimeUtil.to_iso8601(now - 60.0), "arriveAt": TimeUtil.to_iso8601(now + arrive_in),
	}


func _sheet() -> FleetsSheet:
	var s: FleetsSheet = auto_free(SHEET.instantiate())
	add_child(s)
	return s


func test_refresh_splits_incoming_and_own_and_skips_arrived() -> void:
	GameState.apply_fleets([_fleet("a", 7, 600.0), _fleet("b", 9, 300.0), _fleet("c", 7, -5.0), _fleet("d", 7, 100.0)])
	var s := _sheet()
	s.refresh()
	assert_int(s.cards().size()).is_equal(3)
	assert_bool(s.incoming_header.visible).is_true()
	assert_str(s.incoming_header.text).is_equal("NADCHODZĄCE · 1")
	assert_str(s.own_header.text).is_equal("W DRODZE · 2")
	assert_bool(s.empty_label.visible).is_false()
	# kolejność: nagłówek nadchodzących, karta b, nagłówek własnych, karta d (100 s), karta a (600 s)
	var order: Array = []
	for c in s.list.get_children():
		if c is FleetCard:
			order.append((c as FleetCard).fleet.id)
	assert_that(order).is_equal(["b", "d", "a"])


func test_empty_state() -> void:
	var s := _sheet()
	s.refresh()
	assert_int(s.cards().size()).is_equal(0)
	assert_bool(s.incoming_header.visible).is_false()
	assert_bool(s.own_header.visible).is_false()
	assert_bool(s.empty_label.visible).is_true()


func test_card_tap_is_forwarded() -> void:
	GameState.apply_fleets([_fleet("a", 7, 600.0)])
	var s := _sheet()
	s.refresh()
	var got: Array = []
	s.fleet_tapped.connect(func(f: Fleet) -> void: got.append(f.id))
	(s.cards()[0] as FleetCard).tapped.emit((s.cards()[0] as FleetCard).fleet)
	assert_that(got).is_equal(["a"])
```

`test/scenes/dock_test.gd`:

```gdscript
extends GdUnitTestSuite

const DOCK := preload("res://scenes/ui/Dock.tscn")


func before_test() -> void:
	GameState.reset()
	GameState.apply_world({
		"id": "w1", "seed": 1337, "size": {"w": 200, "h": 200},
		"playerId": 7, "homeSettlement": {"x": 103, "y": 100},
	})


func after_test() -> void:
	GameState.reset()


func _fleet(id: String, owner: int, arrive_in: float) -> Dictionary:
	var now := TimeUtil.now()
	return {
		"id": id, "ownerId": owner, "mission": "ATTACK",
		"from": {"x": 0, "y": 0}, "to": {"x": 4, "y": 0},
		"departAt": TimeUtil.to_iso8601(now - 60.0), "arriveAt": TimeUtil.to_iso8601(now + arrive_in),
	}


func _dock() -> CanvasLayer:
	var d: CanvasLayer = auto_free(DOCK.instantiate())
	add_child(d)
	return d


func test_badge_counts_fleets_in_transit() -> void:
	var d := _dock()
	assert_bool(d.badge.visible).is_false()
	GameState.apply_fleets([_fleet("a", 7, 600.0), _fleet("b", 7, -5.0)])
	assert_bool(d.badge.visible).is_true()
	assert_str(d.badge.text).is_equal("1")
	assert_bool(d.is_alarmed()).is_false()


func test_incoming_foreign_fleet_alarms_badge() -> void:
	var d := _dock()
	GameState.apply_fleets([_fleet("a", 9, 600.0)])
	assert_bool(d.is_alarmed()).is_true()


func test_map_button_only_in_settlement_view() -> void:
	var d := _dock()
	SceneManager.view_changed.emit(SceneManager.VIEW_ISLAND_DETAIL)
	assert_bool(d.map_button.visible).is_true()
	SceneManager.view_changed.emit(SceneManager.VIEW_WORLD_MAP)
	assert_bool(d.map_button.visible).is_false()
```

Dopisz do `test/scenes/sheets_test.gd`:

```gdscript
func test_open_fleets_shows_fleets_sheet() -> void:
	var s := _sheets()
	s.open_fleets()
	assert_object(s.current_sheet()).is_same(s.fleets_sheet)
	assert_bool(s.fleets_sheet.visible).is_true()
```

- [ ] **Step 2: Uruchom, oczekuj błędów**

```bash
./run_tests.sh test/scenes/fleet_card_test.gd
./run_tests.sh test/scenes/fleets_sheet_test.gd
./run_tests.sh test/scenes/dock_test.gd
```

- [ ] **Step 3: `scenes/ui/FleetCard.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/ui/FleetCard.gd" id="1"]
[ext_resource type="Script" path="res://scenes/ui/Icon.gd" id="2"]

[node name="FleetCard" type="PanelContainer"]
mouse_filter = 0
theme_type_variation = &"FleetCard"
script = ExtResource("1")

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 2
mouse_filter = 2

[node name="HeaderRow" type="HBoxContainer" parent="VBox"]
layout_mode = 2
mouse_filter = 2

[node name="MissionIcon" type="Control" parent="VBox/HeaderRow"]
layout_mode = 2
script = ExtResource("2")

[node name="Title" type="Label" parent="VBox/HeaderRow"]
layout_mode = 2
size_flags_horizontal = 3
clip_text = true
theme_type_variation = &"Title"

[node name="EtaLabel" type="Label" parent="VBox/HeaderRow"]
layout_mode = 2
theme_type_variation = &"Amount"

[node name="EtaBar" type="ProgressBar" parent="VBox"]
layout_mode = 2
mouse_filter = 2
max_value = 1.0
show_percentage = false

[node name="Composition" type="Label" parent="VBox"]
layout_mode = 2
autowrap_mode = 3
theme_type_variation = &"Caption"
```

- [ ] **Step 4: `scenes/ui/FleetCard.gd`**

```gdscript
class_name FleetCard
extends PanelContainer

## Karta jednej floty: misja i cel, odliczanie, pasek postępu, skład. Lewa krawędź w kolorze misji.

signal tapped(fleet: Fleet)

const ICON := 16.0
const SHIP_LABELS := {"SLOOP": "slup", "GALLEON": "galeon"}

@onready var mission_icon: Icon = $VBox/HeaderRow/MissionIcon
@onready var title: Label = $VBox/HeaderRow/Title
@onready var eta_label: Label = $VBox/HeaderRow/EtaLabel
@onready var eta_bar: ProgressBar = $VBox/EtaBar
@onready var composition: Label = $VBox/Composition

var fleet: Fleet = null


func _ready() -> void:
	mission_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
	title.add_theme_color_override("font_color", MedievalTheme.INK)
	composition.add_theme_color_override("font_color", MedievalTheme.INK_SOFT)
	eta_bar.custom_minimum_size.y = MedievalTheme.px(8)
	gui_input.connect(_on_gui_input)


func refresh(f: Fleet, now: float, player_id: int) -> void:
	fleet = f
	var label: String = Fleet.MISSION_LABELS.get(f.mission, f.mission)
	title.text = "%s → (%d, %d)" % [label, f.to.x, f.to.y]
	eta_label.text = TimeUtil.format_eta(f.remaining_seconds(now))
	eta_bar.value = f.progress(now)
	composition.text = _composition(f) if f.is_own(player_id) else "gracz %d · szczegóły niewidoczne" % f.owner_id
	mission_icon.kind = Fleet.MISSION_ICONS.get(f.mission, &"fleet")
	var accent := MedievalTheme.BRASS
	var bar_variation := &""
	match f.mission:
		"ATTACK":
			accent = MedievalTheme.BLOOD
			bar_variation = &"RaidBar"
		"EXPEDITION":
			accent = MedievalTheme.MOSS
			bar_variation = &"ScoutBar"
	eta_bar.theme_type_variation = bar_variation
	mission_icon.color = accent
	var base := get_theme_stylebox("panel")
	if base is StyleBoxFlat:
		var sb: StyleBoxFlat = base.duplicate()
		sb.border_color = accent
		add_theme_stylebox_override("panel", sb)


func _composition(f: Fleet) -> String:
	var parts: Array[String] = []
	for k in f.ships:
		parts.append("%d × %s" % [int(f.ships[k]), SHIP_LABELS.get(k, k)])
	for k in f.cargo_units:
		parts.append("%d × %s" % [int(f.cargo_units[k]), k])
	for r in ResourceTypes.ALL:
		var amount := float(f.cargo_resources.get(r, 0.0))
		if amount > 0.0:
			parts.append("%s %s" % [TimeUtil.format_thousands(amount), ResourceTypes.LABELS[r].to_lower()])
	return " · ".join(parts)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and fleet != null:
		tapped.emit(fleet)
```

- [ ] **Step 5: `scenes/ui/FleetsSheet.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/ui/FleetsSheet.gd" id="1"]
[ext_resource type="Script" path="res://scenes/ui/Icon.gd" id="2"]

[node name="FleetsSheet" type="PanelContainer"]
visible = false
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 0
mouse_filter = 0
theme_type_variation = &"Sheet"
script = ExtResource("1")

[node name="SheetMargin" type="MarginContainer" parent="."]
layout_mode = 2
mouse_filter = 2

[node name="Body" type="VBoxContainer" parent="SheetMargin"]
layout_mode = 2
mouse_filter = 2

[node name="Grabber" type="Panel" parent="SheetMargin/Body"]
layout_mode = 2
size_flags_horizontal = 4
mouse_filter = 2

[node name="Header" type="PanelContainer" parent="SheetMargin/Body"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"ModalHeader"

[node name="HBox" type="HBoxContainer" parent="SheetMargin/Body/Header"]
layout_mode = 2
mouse_filter = 2

[node name="FleetIcon" type="Control" parent="SheetMargin/Body/Header/HBox"]
layout_mode = 2
script = ExtResource("2")
kind = &"fleet"

[node name="Title" type="Label" parent="SheetMargin/Body/Header/HBox"]
layout_mode = 2
size_flags_horizontal = 3
text = "FLOTY"
theme_type_variation = &"Title"

[node name="CloseButton" type="Button" parent="SheetMargin/Body/Header/HBox"]
layout_mode = 2
size_flags_vertical = 4
theme_type_variation = &"ToolButton"

[node name="Scroll" type="ScrollContainer" parent="SheetMargin/Body"]
layout_mode = 2
size_flags_vertical = 3
horizontal_scroll_mode = 0

[node name="List" type="VBoxContainer" parent="SheetMargin/Body/Scroll"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2

[node name="IncomingHeader" type="Label" parent="SheetMargin/Body/Scroll/List"]
layout_mode = 2
theme_type_variation = &"SectionHeader"

[node name="OwnHeader" type="Label" parent="SheetMargin/Body/Scroll/List"]
layout_mode = 2
theme_type_variation = &"SectionHeader"

[node name="EmptyLabel" type="Label" parent="SheetMargin/Body/Scroll/List"]
layout_mode = 2
text = "Żadna flota nie jest w drodze."
```

- [ ] **Step 6: `scenes/ui/FleetsSheet.gd`**

```gdscript
class_name FleetsSheet
extends PanelContainer

## Lista flot: nadchodzące cudze na górze, własne w drodze poniżej, przybyłe pomijane.
## Karty odświeżane co sekundę, tylko gdy arkusz jest widoczny.

signal fleet_tapped(fleet: Fleet)
signal close_requested

const FLEET_CARD := preload("res://scenes/ui/FleetCard.tscn")
const TICK := 1.0
const ICON := 40.0
const CLOSE := 30.0

@onready var grabber: Panel = $SheetMargin/Body/Grabber
@onready var fleet_icon: Icon = $SheetMargin/Body/Header/HBox/FleetIcon
@onready var close_button: Button = $SheetMargin/Body/Header/HBox/CloseButton
@onready var list: VBoxContainer = $SheetMargin/Body/Scroll/List
@onready var incoming_header: Label = $SheetMargin/Body/Scroll/List/IncomingHeader
@onready var own_header: Label = $SheetMargin/Body/Scroll/List/OwnHeader
@onready var empty_label: Label = $SheetMargin/Body/Scroll/List/EmptyLabel

var _cards: Array = []
var _accum := 0.0


func _ready() -> void:
	SheetStyle.apply_common(self, grabber)
	fleet_icon.custom_minimum_size = Vector2.ONE * MedievalTheme.px(ICON)
	fleet_icon.color = MedievalTheme.CREAM
	close_button.custom_minimum_size = Vector2.ONE * MedievalTheme.px(CLOSE)
	Icon.into_button(close_button, &"close", MedievalTheme.CREAM, MedievalTheme.px(7))
	list.add_theme_constant_override("separation", MedievalTheme.px(10))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	GameState.fleets_updated.connect(_on_fleets_updated)


func cards() -> Array:
	return _cards.duplicate()


func refresh() -> void:
	for c in _cards:
		list.remove_child(c)
		c.queue_free()
	_cards.clear()
	var now := TimeUtil.now()
	var pid := GameState.player_id
	var incoming: Array = []
	var own: Array = []
	for f: Fleet in GameState.fleets.values():
		if f.is_arrived(now):
			continue
		if f.is_own(pid):
			own.append(f)
		else:
			incoming.append(f)
	var by_arrival := func(a: Fleet, b: Fleet) -> bool: return a.arrive_at < b.arrive_at
	incoming.sort_custom(by_arrival)
	own.sort_custom(by_arrival)
	incoming_header.visible = not incoming.is_empty()
	incoming_header.text = "NADCHODZĄCE · %d" % incoming.size()
	own_header.visible = not own.is_empty()
	own_header.text = "W DRODZE · %d" % own.size()
	empty_label.visible = incoming.is_empty() and own.is_empty()
	_insert_cards(incoming, incoming_header, now, pid)
	_insert_cards(own, own_header, now, pid)


## Karty wchodzą zaraz za swoim nagłówkiem, w kolejności przybycia.
func _insert_cards(fleets: Array, header: Label, now: float, pid: int) -> void:
	var index := header.get_index() + 1
	for f: Fleet in fleets:
		var card: FleetCard = FLEET_CARD.instantiate()
		list.add_child(card)
		list.move_child(card, index)
		index += 1
		card.refresh(f, now, pid)
		card.tapped.connect(func(x: Fleet) -> void: fleet_tapped.emit(x))
		_cards.append(card)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_accum += delta
	if _accum < TICK:
		return
	_accum = 0.0
	var now := TimeUtil.now()
	var pid := GameState.player_id
	for c: FleetCard in _cards:
		c.refresh(c.fleet, now, pid)


func _on_fleets_updated() -> void:
	if is_visible_in_tree():
		refresh()
```

- [ ] **Step 7: Podepnij `FleetsSheet` do `Sheets`**

`Sheets.tscn`: `[ext_resource type="PackedScene" path="res://scenes/ui/FleetsSheet.tscn" id="4"]`, `load_steps=5`, węzeł `[node name="FleetsSheet" parent="." instance=ExtResource("4")]` po `Backdrop`. `Sheets.gd`: `@onready var fleets_sheet: FleetsSheet = $FleetsSheet`, w `_ready()` `fleets_sheet.fleet_tapped.connect(_on_fleet_tapped)`, zamień `open_fleets` i dodaj handler:

```gdscript
func open_fleets() -> void:
	fleets_sheet.refresh()
	_open(fleets_sheet, HEIGHT_FLEETS)


## Tap w kartę: arkusz znika, mapa otwiera się na pozycji floty (view_changed zamknie warstwę od razu).
func _on_fleet_tapped(fleet: Fleet) -> void:
	close()
	SceneManager.show_world_map_at(fleet.position_at(TimeUtil.now()))
```

- [ ] **Step 8: `scenes/ui/Dock.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/Dock.gd" id="1"]

[node name="Dock" type="CanvasLayer"]
layer = 11
script = ExtResource("1")

[node name="Root" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="FleetsButton" type="Button" parent="Root"]
theme_type_variation = &"ToolButton"

[node name="Badge" type="Label" parent="Root/FleetsButton"]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
grow_horizontal = 0
theme_type_variation = &"Badge"

[node name="MapButton" type="Button" parent="Root"]
theme_type_variation = &"ToolButton"
```

- [ ] **Step 9: `scenes/ui/Dock.gd`**

```gdscript
extends CanvasLayer

## Dock: „Floty” (z odznaką liczby flot w drodze) zawsze, „Mapa” tylko w widoku osady.
## Cudza flota w drodze barwi odznakę na BLOOD, żeby zagrożenie było widoczne z osady.

const TOOL := 46.0
const MARGIN := 10.0
const TICK := 1.0

@onready var root: Control = $Root
@onready var fleets_button: Button = $Root/FleetsButton
@onready var badge: Label = $Root/FleetsButton/Badge
@onready var map_button: Button = $Root/MapButton

var _accum := 0.0
var _alarmed := false


func _ready() -> void:
	var tool := MedievalTheme.px(TOOL)
	for b in [fleets_button, map_button]:
		b.custom_minimum_size = Vector2(tool, tool)
		b.size = Vector2(tool, tool)
	Icon.into_button(fleets_button, &"fleet", MedievalTheme.CREAM, MedievalTheme.px(10))
	Icon.into_button(map_button, &"map", MedievalTheme.CREAM, MedievalTheme.px(10))
	badge.offset_left = -MedievalTheme.px(14)
	badge.offset_top = -MedievalTheme.px(8)
	fleets_button.pressed.connect(_on_fleets_pressed)
	map_button.pressed.connect(SceneManager.show_world_map)
	SceneManager.view_changed.connect(_sync_visibility)
	GameState.state_loaded.connect(func() -> void: _sync_visibility(SceneManager.current_view))
	GameState.fleets_updated.connect(refresh_badge)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_sync_visibility(SceneManager.current_view)
	refresh_badge()


func is_alarmed() -> bool:
	return _alarmed


func refresh_badge() -> void:
	var now := TimeUtil.now()
	var count := 0
	var alarmed := false
	for f: Fleet in GameState.fleets.values():
		if f.is_arrived(now):
			continue
		count += 1
		if not f.is_own(GameState.player_id):
			alarmed = true
	badge.visible = count > 0
	badge.text = str(count)
	_alarmed = alarmed
	if alarmed:
		badge.add_theme_stylebox_override("normal", MedievalTheme.flat(MedievalTheme.BLOOD, MedievalTheme.BLOOD, 2, 0, 5, 3))
		badge.add_theme_color_override("font_color", MedievalTheme.CREAM)
	else:
		badge.remove_theme_stylebox_override("normal")
		badge.remove_theme_color_override("font_color")


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= TICK:
		_accum = 0.0
		refresh_badge()


## Argument z sygnału view_changed, żeby dock nie zależał od kolejności aktualizacji current_view.
func _sync_visibility(path: String = "") -> void:
	if path.is_empty():
		path = SceneManager.current_view
	map_button.visible = path == SceneManager.VIEW_ISLAND_DETAIL and GameState.world != null


func _layout() -> void:
	var vis := get_viewport().get_visible_rect().size
	var m := MedievalTheme.px(MARGIN)
	var tool := MedievalTheme.px(TOOL)
	var bottom := vis.y - SafeArea.bottom_inset(get_viewport()) - m - tool
	fleets_button.position = Vector2(m, bottom)
	map_button.position = Vector2(vis.x - m - tool, bottom)


func _on_fleets_pressed() -> void:
	var sheets := get_tree().get_first_node_in_group("sheets")
	if sheets != null:
		sheets.open_fleets()
```

- [ ] **Step 10: Dodaj `Dock` do `Main.tscn`**

`[ext_resource type="PackedScene" path="res://scenes/ui/Dock.tscn" id="4"]`, `load_steps=5`, węzeł `[node name="Dock" parent="." instance=ExtResource("4")]` między `HUD` a `Sheets` (kolejność warstw i tak wynika z `layer`).

- [ ] **Step 11: Uruchom testy i smoke**

```bash
./run_tests.sh test/scenes
./run_smoke.sh
```

Oczekiwane: zielono. Jeśli `test_refresh_splits_incoming_and_own_and_skips_arrived` pada na kolejności, sprawdź `move_child` (indeks liczony po `add_child`, więc karta trafia dokładnie za nagłówek).

- [ ] **Step 12: Commit**

```bash
git add scenes/ui/Dock.tscn scenes/ui/Dock.gd scenes/ui/Dock.gd.uid scenes/ui/FleetCard.tscn scenes/ui/FleetCard.gd scenes/ui/FleetCard.gd.uid scenes/ui/FleetsSheet.tscn scenes/ui/FleetsSheet.gd scenes/ui/FleetsSheet.gd.uid scenes/ui/Sheets.tscn scenes/ui/Sheets.gd scenes/views/Main.tscn test/scenes/fleet_card_test.gd test/scenes/fleet_card_test.gd.uid test/scenes/fleets_sheet_test.gd test/scenes/fleets_sheet_test.gd.uid test/scenes/dock_test.gd test/scenes/dock_test.gd.uid test/scenes/sheets_test.gd
git commit -m "Add dock with fleets badge, FleetCard and FleetsSheet"
```

---

### Task 11: Start w osadzie, końcowy smoke test, sprzątanie

**Files:**
- Modify: `scenes/views/Main.gd:8`, `tools/smoke_probe.gd` (całość `_process` i nagłówek), `run_smoke.sh:2`
- Test: `./run_smoke.sh`, `./run_tests.sh`

**Interfaces:**
- Consumes: wszystko z Task 5–10: `HUD.settlement_name`, `pop_label`, `icon_of`; `Dock.fleets_button`, `map_button`; `Sheets.is_open()`, `current_sheet()`, `inspect_sheet`, `building_sheet`, `fleets_sheet`, `backdrop`; `FleetsSheet.cards()`; `WorldMap.camera`; `IslandGenerator._slot_positions`.

- [ ] **Step 1: Start w osadzie** (`scenes/views/Main.gd`)

Zamień linię z `state_loaded.connect(SceneManager.show_world_map, ...)` na:

```gdscript
	GameState.state_loaded.connect(SceneManager.show_island_detail, CONNECT_ONE_SHOT)
```

- [ ] **Step 2: Uruchom stary smoke, oczekuj porażki**

```bash
./run_smoke.sh
```

Oczekiwane: `FAIL widok mapy` (start jest teraz w osadzie) i `SMOKE FAILED`.

- [ ] **Step 3: Przepisz smoke probe** (`tools/smoke_probe.gd`)

Zostaw helpery `_mouse_press`, `_mouse_move`, `_mouse_release`, `_viewport_to_window`, `_viewport_delta_to_window`, `_chip_icon_center`, `_sea_point`, `_control_center`, `_slot_viewport_point`, `_check` bez zmian. Zamień komentarz nagłówkowy na „Smoke test scen: start w osadzie, mapa przez dock, arkusze inspekcji, budynku i flot, powrót do osady.” Dodaj helper:

```gdscript
## Punkt w górnej połowie ekranu, poniżej HUD i powyżej każdego arkusza (backdrop).
func _backdrop_point() -> Vector2:
	var vis := get_viewport().get_visible_rect()
	var hud := get_node("Main/HUD")
	return Vector2(vis.get_center().x, hud.bar_height() + (vis.size.y * 0.5 - hud.bar_height()) * 0.5)


func _sheets() -> CanvasLayer:
	return get_node("Main/Sheets")


func _map() -> Node2D:
	return get_node_or_null("Main/ViewContainer/WorldMap")


func _tap_control(c: Control) -> void:
	var at := _control_center(c)
	_mouse_press(at)
	_mouse_release(at)
```

Zamień całe `_process` na:

```gdscript
func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		20:
			_check(GameState.world != null and GameState.world.id == "w1", "świat załadowany")
			_check(GameState.settlements.size() == 3, "3 osady")
			_check(GameState.fleets.size() == 3, "3 floty")
			_check(
				GameState.active_settlement != null and GameState.active_settlement.name == "Koralowa",
				"osada domowa aktywna"
			)
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "start w widoku osady")
			_check(ThemeDB.get_default_theme().get_type_variation_base(&"Plaque") == &"PanelContainer", "motyw wgrany")
			var hud := get_node("Main/HUD")
			_check(hud.settlement_name.text == "Koralowa", "HUD pokazuje osadę aktywną")
			_check(hud.pop_label.text == "42 / 120", "HUD pokazuje populację")
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			var gen: IslandGenerator = det.get_node("Generator") if det != null else null
			_check(det != null and gen.show_slots and gen._slot_positions.size() == 6, "osada ma 6 slotów")
			var dock := get_node("Main/Dock")
			_check(dock.map_button.visible, "dock pokazuje przycisk mapy w osadzie")
			_check(dock.badge.visible and dock.badge.text == "3", "odznaka flot pokazuje 3")
			_check(dock.is_alarmed(), "odznaka alarmuje o cudzej flocie")
		# --- Tap w slot ratusza otwiera arkusz budynku; backdrop go zamyka. ---
		22:
			var det := get_node("Main/ViewContainer/IslandDetail")
			var at := _viewport_to_window(_slot_viewport_point(det, det.get_node("Generator"), Buildings.Type.TOWN_HALL))
			_mouse_press(at)
			_mouse_release(at)
		25:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.current_sheet() == sheets.building_sheet, "tap w slot otwiera arkusz budynku")
			_check(sheets.building_sheet.name_label.text == "Ratusz", "arkusz pokazuje ratusz")
			_check(sheets.building_sheet.level_badge.text == "LV 1", "arkusz pokazuje poziom 1")
			var at := _viewport_to_window(_backdrop_point())
			_mouse_press(at)
			_mouse_release(at)
		28:
			_check(not _sheets().is_open(), "tap w backdrop zamyka arkusz")
		# --- Dock: przycisk mapy otwiera mapę. ---
		30:
			_tap_control(get_node("Main/Dock").map_button)
		34:
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "przycisk docku otwiera mapę")
			var map := _map()
			_check(map != null and map.get_node("Chunks").get_child_count() > 0, "chunki załadowane")
			_check(map != null and map.get_node("Labels").get_child_count() == 3, "3 etykiety osad")
			_check(not get_node("Main/Dock").map_button.visible, "dock chowa przycisk mapy na mapie")
			if map:
				var bounds := Rect2(Vector2.ZERO, Vector2(GameState.world.size) * WorldGrid.CELL_SIZE)
				_check(bounds.has_point(map.camera.position), "kamera mapy w granicach świata")
		# --- Przeciągnięcie nad otwartym morzem przesuwa mapę. ---
		36:
			_pan_start = _map().camera.position
			_drag_from_win = _viewport_to_window(_sea_point())
			_mouse_press(_drag_from_win)
		38:
			_mouse_move(_drag_from_win, _viewport_to_window(_sea_point() + SEA_DRAG_DELTA))
		40:
			_mouse_release(_viewport_to_window(_sea_point() + SEA_DRAG_DELTA))
			_check(_map().camera.position != _pan_start, "przeciągnięcie nad otwartym morzem przesuwa mapę")
		# --- Przeciągnięcie zaczęte na ikonie zasobu w HUD też przesuwa mapę (dekoracje nie łapią inputu). ---
		42:
			_pan_start = _map().camera.position
			_drag_from_win = _viewport_to_window(_chip_icon_center(get_node("Main/HUD")))
			_mouse_press(_drag_from_win)
		44:
			_mouse_move(_drag_from_win, _viewport_to_window(_chip_icon_center(get_node("Main/HUD")) + BAR_DRAG_DELTA))
		46:
			_mouse_release(_viewport_to_window(_chip_icon_center(get_node("Main/HUD")) + BAR_DRAG_DELTA))
			_check(_map().camera.position != _pan_start, "przeciągnięcie na ikonie zasobu przesuwa mapę")
		# --- Tap cudzej osady otwiera arkusz inspekcji; gest na arkuszu nie rusza mapy. ---
		48:
			_map().camera.position = WorldGrid.cell_to_world(Vector2i(95, 100))
			_mouse_press(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		50:
			_mouse_release(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		53:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.current_sheet() == sheets.inspect_sheet, "tap cudzej osady otwiera arkusz inspekcji")
			_check(sheets.inspect_sheet.subtitle.text.contains("gracz 9"), "arkusz inspekcji pokazuje właściciela")
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "mapa zostaje pod arkuszem")
			_pan_start = _map().camera.position
			_drag_from_win = _control_center(sheets.inspect_sheet)
			_mouse_press(_drag_from_win)
		55:
			_mouse_move(_drag_from_win, _drag_from_win + _viewport_delta_to_window(SEA_DRAG_DELTA))
		57:
			_mouse_release(_drag_from_win + _viewport_delta_to_window(SEA_DRAG_DELTA))
			_check(_map().camera.position == _pan_start, "przeciągnięcie po arkuszu nie rusza mapy")
			var at := _viewport_to_window(_backdrop_point())
			_mouse_press(at)
			_mouse_release(at)
		60:
			_check(not _sheets().is_open(), "backdrop zamyka arkusz inspekcji")
			_map().camera.position = WorldGrid.cell_to_world(Vector2i(95, 98))
			_mouse_press(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		62:
			_mouse_release(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		65:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.inspect_sheet.deposit_header.visible, "wyspa niczyja pokazuje znalezisko")
			sheets.close()
		# --- Tap własnej osady wraca do widoku osady. ---
		68:
			_map().camera.position = WorldGrid.cell_to_world(Vector2i(103, 100))
			_mouse_press(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		70:
			_mouse_release(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		73:
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "tap własnej osady wraca do widoku osady")
			_check(not _sheets().is_open(), "zmiana widoku zamyka arkusze")
		# --- Dock: floty jako arkusz, tap w kartę przenosi na mapę przy flocie. ---
		75:
			_tap_control(get_node("Main/Dock").fleets_button)
		78:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.current_sheet() == sheets.fleets_sheet, "przycisk docku otwiera arkusz flot")
			_check(sheets.fleets_sheet.cards().size() == 3, "arkusz flot ma 3 karty")
			_check(sheets.fleets_sheet.incoming_header.visible, "sekcja nadchodzących widoczna")
			var card: Control = sheets.fleets_sheet.cards()[0]
			var at := _control_center(card)
			_mouse_press(at)
			_mouse_release(at)
		82:
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "tap w kartę floty otwiera mapę")
			_check(not _sheets().is_open(), "arkusz flot zamknięty po tapie")
			var incoming: Fleet = GameState.fleets["f3"]
			var dist := _map().camera.position.distance_to(incoming.position_at(TimeUtil.now()))
			_check(dist < WorldGrid.CELL_SIZE * 2.0, "kamera przy pozycji floty")
			ApiClient.resync()
		88:
			_check(GameState.settlements.size() == 3, "resync zachowuje osady")
			_check(get_node("Main/HUD").pop_label.text == "42 / 120", "HUD po resyncu")
			_tap_control(_map().back_plaque)
		92:
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "plakietka OSADA wraca do osady")
			print("SMOKE %s" % ("FAILED" if _failed else "PASSED"))
			get_tree().quit(1 if _failed else 0)
```

Uwagi:
- Karta `cards()[0]` to pierwsza w kolejności listy, czyli nadchodząca cudza flota `f3` (jedyna w sekcji „NADCHODZĄCE”), dlatego sprawdzamy pozycję `f3`.
- `_sheets().close()` w klatce 65 zamiast tapu w backdrop: arkusz inspekcji ma 1/3 ekranu, więc `_backdrop_point()` też by zadziałał; użycie API skraca test.
- `SEA_DRAG_DELTA` i `BAR_DRAG_DELTA` zostają. Komentarz o `BAR_DRAG_DELTA` zaktualizuj: pasek ma teraz około 400 px wysokości, gest pozostaje poziomy.

- [ ] **Step 4: Zaktualizuj komentarz w `run_smoke.sh`**

```sh
# Headless smoke test scen: ładuje Main przez tools/Smoke.tscn i sprawdza przepływ osada -> mapa -> arkusze -> osada.
```

- [ ] **Step 5: Uruchom smoke i wszystkie testy**

```bash
./run_smoke.sh
./run_tests.sh
```

Oczekiwane: każda linia `OK`, `SMOKE PASSED`, kod 0; gdUnit bez błędów. Jeśli któryś krok smoke pada:
- „tap w slot otwiera arkusz budynku”: sprawdź, czy `IslandDetail._slot_under` używa `get_canvas_transform()` tego samego widoku i czy kamera osady została przesunięta przez `_layout()` (probe liczy punkt przez `det.get_canvas_transform()`, więc przesunięcie kamery jest uwzględnione).
- „przeciągnięcie po arkuszu nie rusza mapy”: arkusz musi mieć `mouse_filter = 0` (STOP); `SheetMargin` i dzieci mają `2` (IGNORE), a to nie blokuje, bo hit test schodzi do dzieci, a potem sprawdza rodzica.
- „kamera przy pozycji floty”: `show_world_map_at` ustawia `map_camera_state.position` przed podmianą, a `_ready` mapy czyta ją przed `set_bounds`.

- [ ] **Step 6: Sprzątanie i przegląd wobec specu**

```bash
grep -rn "BuildingMenu\|BAR_HEIGHT\|EMPTY_SLOT\|SLOT_HIT\|hexagon\|InfoPanel\|BackButton" scenes scripts test tools || echo "czysto"
git status --short
```

Oczekiwane: `czysto` i tylko zamierzone zmiany. Otwórz projekt w edytorze (`"$GODOT" --path . -e`) i uruchom grę (F5): sprawdź na oko górny pasek, plakietki slotów, arkusz budynku, mapę z plakietką OSADA, arkusz inspekcji, dock i arkusz flot, a potem obróć okno do landscape (zmiana rozmiaru okna) i sprawdź, że karty zasobów przenoszą się do wiersza profilu.

- [ ] **Step 7: Commit i zakończenie**

```bash
git add scenes/views/Main.gd tools/smoke_probe.gd run_smoke.sh
git commit -m "Start in the active settlement and cover the sheet-based flow in the smoke test"
git log --oneline feat/client-skeleton..HEAD
```

Oczekiwane: 11 commitów od Task 1 do Task 11. Dalej: skill `superpowers:finishing-a-development-branch` (merge do `feat/client-skeleton` albo PR), worktree `.worktree/ui-v2` usuwany dopiero po integracji.

---

## Samoprzegląd planu wobec specu

| Sekcja specu | Zadanie |
|---|---|
| 3.1 `Main.tscn` (morze, chrome) | Task 4, 8, 10 |
| 3.2 `SceneManager` (pamięć kamery, `show_world_map_at`, fade) | Task 6 |
| 3.3 Dock | Task 10 |
| 3.4 Widok osady | Task 8 |
| 3.5 Mapa (UI, kolory, tap) | Task 9 |
| 3.6 `Sheets` | Task 8, 9, 10 |
| 3.7 `SafeArea` | Task 4 |
| 4.1 Fonty | Task 1 |
| 4.2 `MedievalTheme` | Task 1 |
| 4.3 `Icon` | Task 2 |
| 4.4 Stałe domenowe | Task 2, 3 |
| 5 HUD | Task 5 |
| 6 `SlotPlaque`, `BuildingSheet` | Task 7, 8 |
| 7 `InspectSheet` | Task 9 |
| 8 `FleetCard`, `FleetsSheet` | Task 10 |
| 9 Obsługa błędów | Task 2 (nieznany kind), 8 (budynek poza biomem), 9 (morze), 10 (nieznana misja), 8 (brak osady) |
| 10 Testy | Task 1–11 |
| 11 Co znika | Task 5 (`BAR_HEIGHT`), 7 (sloty), 8 (`BuildingMenu`, `InfoPanel`, `BackButton`), 4 (`Background`) |
| 12 Kolejność, worktree | Task 0, kolejność zadań |

Spec 3.2 mówi o starcie w osadzie w kroku 4; plan przenosi to do Task 11, żeby smoke test był zielony po każdym zadaniu. Spec 3.5 mówi o siatce wody `SEA.darkened(0.25)`; plan używa półprzezroczystej czerni o tym samym efekcie, bo stała w GDScript nie może wołać metody.
