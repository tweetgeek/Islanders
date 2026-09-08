# Islanders – UI v2 „Chart & Timber” (klient Godot 4)

Data: 2026-09-08
Status: zatwierdzony w brainstormingu, czeka na plan implementacji
Źródło wizualne: projekt Claude Design „Islanders UI v2.dc.html” (wariant 2A, „Chart & Timber”)
oraz drzewo węzłów i `HUDController.gd` z „Islanders UI.dc.html” (wersja 1).
Poprzedni spec: `2026-09-07-islanders-client-skeleton-design.md`; ten dokument go nie zastępuje,
tylko nadpisuje sekcje o `Main`, HUD, `IslandDetail`, `BuildingMenu` i nawigacji.

Terminologia zgodna z `CONTEXT.md`. Glosariusz ma pierwszeństwo.

## 1. Cel

Nadać klientowi PoC spójną szatę graficzną z projektu „Chart & Timber” (dębowy chrome,
mosiężne linie, pergaminowe karty; morze jako jedyna ciemna powierzchnia) i zmienić model
nawigacji z „mapa jako dom” na „osada aktywna jako dom, mapa jako narzędzie, reszta jako
arkusze nad widokiem”.

W zakresie: motyw i fonty, ikony rysowane kodem, górny pasek HUD, widok osady z plakietkami
slotów, arkusz budynku, mapa z warstwą UI, arkusz inspekcji cudzej i niczyjej wyspy, dock,
arkusz flot, zarządca arkuszy, smoke test nowego przepływu.

Poza zakresem: zakładka Alliance (brak w domenie), złoto jako dane, koszty i czas budowy
(brak w kontrakcie API), floty bezczynne (garnizon nie przychodzi z API), wariant modalu
„dialog na środku”, kompas i linia rumbowa na mapie, boczne narzędzia (młotek, zwój),
licznik rolujący zasobów, akcje na wyspie (wyprawa, kolonizacja, atak), emoji.

## 2. Decyzje

| Decyzja | Wybór | Uzasadnienie |
|---|---|---|
| Model nawigacji | Osada aktywna jako dom, mapa jako pełnoekranowe narzędzie, reszta jako arkusze | Gra mobilna: w osadzie wydaje się najwięcej poleceń; mapa służy flotom i podglądowi konkurencji |
| Widoki | Dwa: `IslandDetail` (osada aktywna) i `WorldMap`, podmieniane przez `SceneManager` | Jedna aktywna `Camera2D`, istniejący wzorzec, małe sceny |
| Chrome | Trwałe warstwy w `Main`: HUD, Dock, Sheets | Przeżywają podmianę widoku, jeden backdrop |
| Arkusze | Zawsze od dołu (`Bottom Wide`), co najwyżej jeden otwarty | Jedna ścieżka animacji |
| Motyw | `MedievalTheme.build()` w `Main._ready()`, bez pliku `.theme` | Brak binariów w repo, testowalne headless |
| Fonty | Cinzel Bold, Spectral Regular i SemiBold (OFL) w `res://ui/fonts/` | Wierność projektowi; licencja pozwala na dystrybucję |
| Ikony | Klasa `Icon` z `_draw()`, płaskie glify z palety | Domyślny font Godota nie renderuje emoji; zero zewnętrznych grafik |
| Zasoby w HUD | Pięć kart `ResCard` plus placeholder złota | Domena ma pięć zasobów bez złota; miejsce na przyszłą walutę |
| Profil w HUD | Nazwa osady aktywnej, odznaka biomu, podpis ze światem i współrzędnymi | Gracz nie ma poziomu ani nazwy w domenie |
| Cudza / niczyja wyspa | Arkusz `InspectSheet` nad mapą | Nie wyrzuca gracza z mapy |
| Koszty w arkuszu budynku | Węzły istnieją, ukryte, metody `refresh_*` publiczne | Kontrakt API ich nie ma; scena gotowa na przyszłość |
| Skala | `MedievalTheme.SCALE = 2.77` (1080 / 390) | Projekt jest dla 390 px, viewport ma 1080 px |
| Środowisko pracy | Osobny git worktree w `.worktree/` | Życzenie użytkownika; `.worktree/` w `.gitignore` |

## 3. Struktura scen i nawigacja

### 3.1 `Main.tscn`

```
Main (Control, Full Rect, mouse_filter = PASS, theme = MedievalTheme.build())   Main.gd
├── SeaBackground (CanvasLayer, layer -100)
│   └── Sea (ColorRect, Full Rect, mouse_filter = IGNORE, color = MedievalTheme.SEA)
├── ViewContainer (Node)                       ← SceneManager wstawia WorldMap albo IslandDetail
├── HUD (CanvasLayer, layer 10)                 HUD.tscn
├── Dock (CanvasLayer, layer 11)                Dock.tscn
└── Sheets (CanvasLayer, layer 12)              Sheets.tscn
```

Tło morza przenosi się z `WorldMap.tscn` i `IslandDetail.tscn` do `Main`. Oba widoki tracą
własne `Background`.

`Main._ready()`: buduje motyw, rejestruje kontener, po `state_loaded` woła
`SceneManager.show_island_detail()` (start w osadzie, nie na mapie), łączy
`Sheets.upgrade_requested` z `print`, jak dziś `IslandDetail`.

### 3.2 `SceneManager`

- Dwa widoki bez zmian: `VIEW_WORLD_MAP`, `VIEW_ISLAND_DETAIL`; metody `show_world_map()`,
  `show_island_detail()`; sygnał `view_changed(view_path)`.
- Nowe: `map_camera_state: Dictionary` (pusty na starcie; klucze `position: Vector2`,
  `zoom: Vector2`). `WorldMap._exit_tree()` zapisuje, `WorldMap._ready()` odczytuje; przy
  pustym słowniku mapa centruje na osadzie aktywnej.
- Nowe: `show_world_map_at(world_pos: Vector2)`. Gdy mapa nie jest otwarta: ustawia
  `map_camera_state.position = world_pos` (zoom bez zmian) i podmienia widok. Gdy mapa jest
  otwarta: woła `WorldMap.focus(world_pos)` bez podmiany.
- Fade: wchodzący widok dostaje `modulate.a` od 0 do 1 w 0,18 s (`TRANS_CUBIC`, `EASE_OUT`).
  Wychodzący jest usuwany od razu przez `queue_free`, bez animacji. Ten sam widok drugi raz:
  bez akcji.

### 3.3 Dock

```
Dock (CanvasLayer, layer 11)                      Dock.gd
├── FleetsButton (Button, wariacja ToolButton, lewy dolny róg nad safe area, Icon "fleet")
│   └── Badge (Label, wariacja Badge, prawy górny róg przycisku)
└── MapButton (Button, wariacja ToolButton, prawy dolny róg nad safe area, Icon "map")
```

- `MapButton` woła `SceneManager.show_world_map()`. Widoczny tylko w widoku osady i tylko gdy
  `GameState.world != null`. Na mapie jego miejsce zajmują przyciski zoomu (3.5).
- `FleetsButton` widoczny zawsze, woła `Sheets.open_fleets()`.
- `Badge` po `fleets_updated` i co sekundę w `_process`: liczba flot z `GameState.fleets`,
  dla których `not is_arrived(TimeUtil.now())`. Ukryta przy zerze. Jeśli wśród nich jest choć
  jedna cudza (`not is_own(GameState.player_id)`), tło odznaki ma kolor `BLOOD` zamiast
  `BRASS`.
- Dock słucha `SceneManager.view_changed` i przełącza widoczność.

### 3.4 Widok osady `IslandDetail.tscn`

```
IslandDetail (Node2D)                              IslandDetail.gd
├── Generator (IslandGenerator, radius = 400, show_slots = true)
├── Camera (Camera2D)
└── UI (CanvasLayer, layer 1)
    └── HintPanel (PanelContainer, wariacja Plaque, lewy dolny róg nad dockiem)
        └── Label (Caption): "Dotknij slotu, żeby otworzyć budynek"
```

- Pokazuje wyłącznie `GameState.active_settlement`. Słucha `active_settlement_changed` oraz
  `settlement_updated(coord)` dla współrzędnych osady aktywnej; każdy z nich przebudowuje
  generator (`set_settlement`, `build()`).
- Brak przycisku powrotu, brak `InfoPanel`, brak `BuildingMenu`. Tryby „cudza” i „niczyja”
  znikają z tego widoku (przechodzą do `InspectSheet`, 3.6).
- Kamera centruje wyspę w obszarze między dołem paska HUD (`HUD.bar_height()`) a górą docku.
  Przeliczane w `_ready` i po `size_changed`.
- Brak osady aktywnej: generator pusty (`build()` nie jest wołany), `HintPanel` pokazuje
  „Brak osady”.
- Dotyk: `_unhandled_input` jak dziś, przez `generator.slot_at(local)`. Trafienie woła
  `Sheets.open_building(settlement, building)` i ukrywa `HintPanel` na stałe dla tej
  instancji widoku.

### 3.5 Mapa `WorldMap.tscn`

```
WorldMap (Node2D)                                  WorldMap.gd
├── Water, Chunks, Labels, Fleets, Camera          bez zmian
└── UI (CanvasLayer, layer 1)
    ├── BackPlaque (Button, ToolButton, lewy górny róg pod HUD, Icon "back" + tekst "OSADA")
    ├── CoordPanel (PanelContainer, wariacja Chip, prawy górny róg pod HUD)
    │   └── Label: "X 10 · Y 15 · zoom 0.8"
    └── ZoomControls (VBoxContainer, prawy dolny róg nad safe area)
        ├── ZoomIn (Button, ToolButton, Icon "plus")
        └── ZoomOut (Button, ToolButton, Icon "minus")
```

- `BackPlaque` woła `SceneManager.show_island_detail()`.
- `CoordPanel` odświeżany w `_process`: komórka pod środkiem ekranu
  (`WorldGrid.world_to_cell(camera.position)`) i `camera.zoom.x` z jednym miejscem po przecinku.
- `ZoomIn` i `ZoomOut` wołają `MapCamera.zoom_by(1.25)` i `zoom_by(0.8)`; `zoom_by(factor)`
  to publiczny wrapper `_zoom_at(środek ekranu, factor)`.
- `WorldMap.focus(world_pos)`: ustawia `camera.position = world_pos`, clampuje, zeruje inercję.
- Pamięć kamery: `_exit_tree()` zapisuje `position` i `zoom` do
  `SceneManager.map_camera_state`; `_ready()` odczytuje.
- Wygląd: woda zostaje w `MedievalTheme.SEA`, siatka w ciemniejszym odcieniu
  (`SEA.darkened(0.25)`). Etykiety osad: własne `BRASS`, cudze `CREAM_SOFT`, wariacja `Title`.
  Pierścień osady w tych samych kolorach. Znacznik znaleziska bez zmian. Mapa nie dostaje
  papierowego tła z mocka: morze jest jedyną ciemną powierzchnią i pozostaje morzem.
- Tap (`_on_tapped`): trafienie w wyspę jak dziś. Własna osada: `set_active_settlement(cell)`
  i `SceneManager.show_island_detail()`. Cudza osada albo wyspa niczyja: `GameState.inspect(cell)`
  i `Sheets.open_inspect(cell)`. `Sheets` nie słucha `inspected_island_changed`; jedna droga.

### 3.6 Zarządca arkuszy `Sheets.tscn`

```
Sheets (CanvasLayer, layer 12, visible = false)   Sheets.gd
├── Backdrop (ColorRect, Full Rect, mouse_filter = STOP, color = (0.08, 0.04, 0.0, 0.55))
├── FleetsSheet (PanelContainer, Bottom Wide, wariacja Sheet, mouse_filter = STOP)   FleetsSheet.gd
├── InspectSheet (PanelContainer, Bottom Wide, wariacja Sheet, mouse_filter = STOP)  InspectSheet.gd
└── BuildingSheet (PanelContainer, Bottom Wide, wariacja Sheet, mouse_filter = STOP) BuildingSheet.gd
```

API `Sheets`: `open_fleets()`, `open_inspect(coord: Vector2i)`,
`open_building(settlement: Settlement, building: Buildings.Type)`, `close()`,
sygnał `upgrade_requested(coord: Vector2i, building: Buildings.Type)` przekazany z `BuildingSheet`.

- Co najwyżej jeden arkusz otwarty (`_current`). Otwarcie innego przy otwartym: poprzedni
  znika bez animacji, nowy wjeżdża z animacją.
- Otwarcie: warstwa `visible = true`, backdrop `modulate.a` 0 → 1 w 0,18 s, arkusz
  `position.y` od `size.y` → 0 w 0,26 s, `TRANS_CUBIC`, `EASE_OUT`. Zamknięcie odwrotnie
  z `EASE_IN`; po zakończeniu `visible = false`. Jeden `Tween` w polu, zabijany przy nowym.
- Tap w backdrop (`InputEventScreenTouch.pressed`) zamyka.
- Słucha `SceneManager.view_changed` i zamyka bez animacji.
- Wysokości arkuszy: `InspectSheet` ok. 1/3 ekranu, `BuildingSheet` ok. 1/2,
  `FleetsSheet` ok. 2/3; ustawione przez `custom_minimum_size.y` = ułamek
  `get_viewport().get_visible_rect().size.y`, przeliczane przy `size_changed`.
- Każdy arkusz ma `Grabber` (Panel 44 × 4 × SCALE, kolor `OAK_EDGE`) i nagłówek
  w wariacji `ModalHeader` z `CloseButton` (Icon `close`) wołającym `Sheets.close()`.

Wyjątek od reguły „widoki tylko przez `SceneManager`”: widoki wołają `Sheets` bezpośrednio
(`open_building`, `open_inspect`), bo arkusze są częścią chrome, nie widokiem.

### 3.7 `SafeArea.gd`

Statyczna klasa w `scenes/ui/`: `static func top_inset(viewport: Viewport) -> float` i
`bottom_inset(viewport) -> float`, przeniesiona logika z obecnego `HUD._apply_safe_area()`
(piksele okna → piksele canvasu). Używana przez HUD, Dock, `IslandDetail` (kamera)
i `WorldMap` (warstwa UI).

## 4. Motyw i assety

### 4.1 Fonty

`res://ui/fonts/`: `Cinzel-Bold.ttf`, `Spectral-Regular.ttf`, `Spectral-SemiBold.ttf`,
`OFL-Cinzel.txt`, `OFL-Spectral.txt`. Źródło: repozytoria Google Fonts na GitHubie.
Pliki `.import` i `.uid` śledzone w git.

### 4.2 `MedievalTheme.gd`

`scenes/ui/MedievalTheme.gd`, `class_name MedievalTheme extends RefCounted`, bez `@tool`.

- Stałe kolorów jeden do jednego z projektu: `PARCHMENT`, `VELLUM`, `CHART`, `RULE`, `OAK`,
  `OAK_DEEP`, `OAK_EDGE`, `BRASS`, `BRASS_HOT`, `INK`, `INK_SOFT`, `CREAM`, `CREAM_SOFT`,
  `SEA`, `BLOOD`, `MOSS`, plus `SECTION = Color("7a4a18")`, `RATE = Color("3f6033")`,
  `RAID = Color("9e3b32")`, `SHORT_BG = Color("e7c9c4")`.
- `const SCALE := 2.77`. `flat()` i `plaque()` mnożą promień, szerokość obramowania,
  marginesy i cień przez `SCALE`. Rozmiary fontów w `build()` = wartość z projektu × `SCALE`,
  zaokrąglone do całości.
- Fonty przez `preload`. `build_and_save()` nie wchodzi.
- Wariacje, które wchodzą: `Label`: `Title`, `Caption`, `SectionHeader`, `Amount`, `Rate`,
  `Badge`. `PanelContainer`: `BarPanel`, `ResCard`, `Chip`, `Plaque`, `Sheet`, `ModalHeader`,
  `FleetCard`. `Button`: `Primary`, `Danger`, `ToolButton`. `ProgressBar`: `RaidBar`,
  `ScoutBar`. Plus style bazowe `Label`, `PanelContainer`, `Button`, `ProgressBar`,
  `LineEdit`, `ScrollContainer`, `HSeparator`, stałe separacji `VBoxContainer`/`HBoxContainer`.
- Wypadają: `NavButton`, `TextureButton`. `ToolButton` staje się wariacją `Button`:
  tło `OAK`, obramowanie `BRASS` 2 × SCALE, promień 5 × SCALE, `custom_minimum_size`
  46 × 46 × SCALE ustawiane w scenach; `hover`/`pressed` z tłem `OAK_DEEP`.

### 4.3 `Icon.gd`

`scenes/ui/Icon.gd`, `class_name Icon extends Control`. `@export var kind: StringName`,
`@export var color: Color = MedievalTheme.INK`. `_draw()` rysuje glif na siatce 24 × 24
przeskalowanej do `size` (`min(size.x, size.y) / 24`). `custom_minimum_size` ustawia scena.
Nieznany `kind`: kółko z obrysem i `push_warning` raz na instancję.

| kind | glif |
|---|---|
| `wood` | dwie ukośne belki |
| `stone` | sześciokąt |
| `food` | łodyga z trzema kropkami |
| `iron` | sztabka (trapez) |
| `sulfur` | trójkąt z kropką |
| `town_hall` | dom z wieżą |
| `barracks` | tarcza |
| `shipyard` | kotwica |
| `warehouse` | skrzynia |
| `anchor` | kotwica (awatar) |
| `map` | rozłożona mapa (prostokąt z zygzakiem) |
| `fleet` | żagiel (trójkąt na maszcie) |
| `people` | dwie sylwetki |
| `gold` | moneta (koło z kołem) |
| `plus`, `minus`, `close`, `back` | krzyż, kreska, X, strzałka w lewo |
| `raid` | skrzyżowane miecze |
| `trade` | skrzynia z pasem |
| `scout` | luneta |
| `colonize` | flaga |
| `return` | strzałka zawracająca |

Budynki wydobywcze używają ikony swojego zasobu (`Buildings.EXTRACTS`).

### 4.4 Stałe domenowe

- `ResourceTypes.ICONS: Dictionary` (klucz zasobu → `kind`).
- `Buildings.ICONS: Dictionary` (typ → `kind`; wydobywcze przez `EXTRACTS`),
  `Buildings.DESCRIPTIONS: Dictionary` (typ → jedno zdanie po polsku).
- `Fleet.MISSION_LABELS`
  (`COLONIZE` „Kolonizacja”, `ATTACK` „Atak”, `TRANSPORT` „Transport”, `EXPEDITION` „Wyprawa”,
  `RETURN` „Powrót”), `Fleet.MISSION_ICONS` (`ATTACK` → `raid`, `TRANSPORT` → `trade`,
  `EXPEDITION` → `scout`, `COLONIZE` → `colonize`, `RETURN` → `return`).
- `TimeUtil.format_thousands(value: float) -> String`: `floor`, grupy po trzy cyfry
  rozdzielone wąską spacją U+2009; od `10 000 000` w górę skrót `10.0M`; liczby ujemne z minusem.

`ResourceTypes.COLORS` i `Biome.COLORS` zostają dla mapy i generatora.

## 5. Górny pasek HUD

```
HUD (CanvasLayer, layer 10)                                        HUD.gd
└── TopBar (PanelContainer, Top Wide, wariacja BarPanel, offset_top = SafeArea.top_inset)
    └── Pad (MarginContainer, margines 12 × SCALE)
        └── BarRows (VBoxContainer, separacja 9 × SCALE)
            ├── ProfileRow (HBoxContainer, separacja 10 × SCALE)
            │   ├── Avatar (Icon "anchor", 40 × 40 × SCALE, color CREAM)
            │   ├── Identity (VBoxContainer, EXPAND_FILL)
            │   │   ├── NameRow (HBoxContainer)
            │   │   │   ├── SettlementName (Label, Title, clip_text = true)
            │   │   │   └── BiomeBadge (Label, Badge, np. "TROPICAL")
            │   │   └── Subtitle (Label, Caption, "Świat w1 · (10, 15)")
            │   └── GoldPanel (PanelContainer, Chip) → HBox: Icon "gold" (BRASS) + GoldLabel "0"
            ├── ResourceGrid (HBoxContainer, separacja 6 × SCALE)
            │   └── ResCard × 5 (PanelContainer, ResCard, EXPAND_FILL), kolejność ResourceTypes.ALL
            │       └── VBoxContainer
            │           ├── TopRow (HBoxContainer): Icon zasobu (ResourceTypes.COLORS) + Amount (Label, Amount)
            │           └── Rate (Label, Rate)
            └── PopulationRow (HBoxContainer, separacja 8 × SCALE)
                ├── PopIcon (Icon "people", INK_SOFT)
                ├── PopBar (ProgressBar, EXPAND_FILL, show_percentage = false)
                └── PopLabel (Label, Amount)
```

- Dane i sygnały bez zmian wobec szkieletu: osada aktywna, `active_settlement_changed`,
  `settlement_updated`, `_process` z `current_resources(TimeUtil.now())`.
- `Amount`: `TimeUtil.format_thousands`; poniżej 700 px szerokości viewportu
  `TimeUtil.format_amount` (`1.2k`).
- `Rate`: `"+%d/h"` z `production_per_hour`. Zasób nieprodukowany (`not produces(r)`):
  `Rate.text = ""`, karta `modulate.a = 0.45`.
- `PopBar.max_value = max(population_max, 1)`, `value = population`. `PopLabel` w kolorze
  `BLOOD`, gdy `population >= population_max * 0.95`, inaczej `INK`.
- `GoldPanel`: `"0"`, niepodpięty; komentarz w scenie „placeholder pod przyszłą walutę”.
- Brak osady: `SettlementName = "-"`, odznaka i podpis puste, karty `"0"`.
- Orientacja: przy `size_changed`, gdy szerokość > wysokość, `ResourceGrid` przenosi się
  jako ostatnie dziecko `ProfileRow` z `EXPAND_FILL`; w portrecie wraca do `BarRows` na
  indeks 1.
- `bar_height() -> float`: `TopBar.offset_top + TopBar.size.y`. Stała `BAR_HEIGHT` znika.
- Licznik rolujący z projektu nie wchodzi.

## 6. Widok osady: plakietki slotów i arkusz budynku

### 6.1 `SlotPlaque.gd`

`scenes/procedural/SlotPlaque.gd`, `class_name SlotPlaque extends Node2D`. Zastępuje
sześciokąt, `Label` i `Area2D` z `IslandGenerator._add_slot`.

- Pola: `building: Buildings.Type`, `level: int`, `pressed: bool`.
- `_draw()`: prostokąt 160 × 155 px (stały w pikselach świata; kamera osady nie zoomuje),
  promień 14 px. Warstwy: cień `OAK_DEEP` przesunięty o 8 px w dół; twarz `PARCHMENT`
  z obramowaniem `OAK` 6 px. Przy `pressed` twarz przesunięta o 8 px w dół, cień ukryty.
  Poziom 0: twarz `PARCHMENT` z alfą 0,35, obramowanie przerywane `OAK_EDGE` (segmenty
  rysowane `draw_dashed_line`), bez cienia.
- Dzieci: `Icon` budynku (56 × 56 px, `INK`; przy poziomie 0 `plus` w `OAK_DEEP`) i `Label`
  w wariacji `Badge` z `"LV %d"` (ukryty przy poziomie 0). Kontrolki jako dzieci `Node2D`
  z `mouse_filter = IGNORE`.
- `contains(local: Vector2) -> bool`: prostokąt trafienia bez cienia.

### 6.2 `IslandGenerator`

- `_add_slot` tworzy `SlotPlaque` zamiast poprzednich węzłów. `slot_at(local_pos)` iteruje
  plakietki i używa `contains`. Stałe `SLOT_SIZE`, `SLOT_HIT`, `EMPTY_SLOT_*` znikają.
- `set_pressed(slot_index, pressed)` do stanu wciśnięcia podczas przytrzymania.
- Pozycje slotów bez zmian (Town Hall w centrum, reszta na okręgu `radius × SLOT_RING`).
- `show_slots = false` (mapa): plakietki nie powstają, jak dziś.

### 6.3 Dotyk w `IslandDetail`

`InputEventScreenTouch.pressed` na slocie: `set_pressed(i, true)`. Puszczenie: `set_pressed(i, false)`;
jeśli puszczono w tym samym slocie, `Sheets.open_building(settlement, building)`.
`InputEventScreenDrag` poza slot: zdejmuje stan wciśnięcia.

### 6.4 `BuildingSheet`

```
BuildingSheet (PanelContainer, Sheet)                           BuildingSheet.gd
└── SheetMargin (MarginContainer, 14 × SCALE) → ModalBody (VBoxContainer, separacja 11 × SCALE)
    ├── Grabber
    ├── Header (PanelContainer, ModalHeader)
    │   └── HBox: BuildingIcon (Icon, 46 × SCALE, CREAM) · TitleBox (VBox, EXPAND_FILL) · CloseButton
    │       TitleBox: NameRow (HBox: Name (Title), LevelBadge (Badge)) + Subtitle (Caption, "Koralowa · slot 3 z 6")
    ├── Description (Label, autowrap WORD_SMART, Buildings.DESCRIPTIONS)
    ├── CostSection (VBoxContainer, visible = false)
    │   ├── CostHeader (Label, SectionHeader, "KOSZT ULEPSZENIA DO n")
    │   └── CostGrid (GridContainer, columns = 5) → CostChip × 5 (PanelContainer, Chip: Icon + Label)
    ├── TimerSection (VBoxContainer, visible = false)
    │   ├── TimerRow (HBox: TimerHeader (SectionHeader, "BUDOWA"), TimerLabel (Amount))
    │   └── ConstructionBar (ProgressBar)
    └── ActionRow (HBoxContainer, separacja 8 × SCALE)
        ├── CancelButton (Button, Danger, "ZAMKNIJ", min_y 48 × SCALE, stretch_ratio 1)
        └── UpgradeButton (Button, Primary, "ULEPSZ" / "BUDUJ" przy poziomie 0, stretch_ratio 2)
```

- `open(settlement, building)`: nagłówek, opis, `LevelBadge = "LV %d"`; numer slotu to indeks
  w `Biome.slots(settlement.biome)` + 1. Sekcje kosztu i licznika pozostają ukryte.
- `refresh_costs(costs: Dictionary, stock: Dictionary)`: pokazuje `CostSection`, chip
  zasobu widoczny gdy `costs[r] > 0`; przy `stock[r] < costs[r]` chip ma tło `SHORT_BG`,
  obramowanie i tekst `BLOOD`.
- `refresh_timer(remaining: float, total: float)`: pokazuje `TimerSection`, `TimerLabel`
  w formacie `hh:mm:ss`, `ConstructionBar.value = 1 - remaining / max(total, 0.001)`,
  `UpgradeButton.disabled = remaining > 0`. Odliczanie w `_process` tylko gdy sekcja widoczna.
- `UpgradeButton`: emituje `upgrade_requested(coord, building)` i woła `Sheets.close()`.
  `CancelButton` i `CloseButton`: `Sheets.close()`.
- `BuildingMenu.tscn` i `BuildingMenu.gd` znikają.

## 7. Arkusz inspekcji

```
InspectSheet (PanelContainer, Sheet)                            InspectSheet.gd
└── SheetMargin → VBoxContainer
    ├── Grabber
    ├── Header (ModalHeader): BiomeIcon (Icon pierwszego zasobu biomu, CREAM) · Name (Title) · BiomeBadge (Badge) · CloseButton
    ├── Subtitle (Caption): "(14, 9) · gracz 12"  |  "(14, 9) · wyspa niczyja"
    └── Body (VBoxContainer)
        ├── PublicLabel (Label): "Dane publiczne: nazwa i właściciel."          (cudza osada)
        ├── DepositHeader (SectionHeader, "ZNALEZISKO") + DepositRow (HBox chipów Chip: Icon + ilość)  (niczyja z deposit)
        └── EmptyLabel (Label, "Brak znaleziska.")                                 (niczyja bez deposit)
```

- `open(coord)`: `Island` z `GameState.island_at(coord)`, `Settlement` z `settlement_at(coord)`.
  Nazwa cudzej osady z `Settlement.name`; wyspa niczyja ma nazwę „Wyspa (x, y)”.
- Widoczne jest dokładnie jedno z trzech dzieci `Body`.
- `Sheets.open_inspect` na komórce bez wyspy: `push_error`, arkusz się nie otwiera.
- Bez akcji (wyprawa, kolonizacja, atak): poza zakresem.

## 8. Arkusz flot i karta floty

### 8.1 `FleetCard.tscn`

`scenes/ui/FleetCard.tscn`, `class_name FleetCard extends PanelContainer`, wariacja `FleetCard`.

```
VBoxContainer
├── HeaderRow (HBox): MissionIcon (Icon) · Title (Label, Title, INK, EXPAND_FILL) · EtaLabel (Label, Amount)
├── EtaBar (ProgressBar, show_percentage = false)
└── Composition (Label, Caption, INK_SOFT)
```

- `refresh(fleet: Fleet, now: float)`:
  - `Title`: `"%s → (%d, %d)"` z `Fleet.MISSION_LABELS[mission]` i `fleet.to`.
  - `EtaLabel`: `mm:ss` z `remaining_seconds(now)`; powyżej godziny `h:mm:ss`.
  - `EtaBar.value = progress(now)` (`max_value = 1`).
  - `Composition` dla własnej: statki (`"%d × %s"` po polsku: `SLOOP` „slup”, `GALLEON`
    „galeon”), jednostki z `cargo_units`, zasoby z `cargo_resources` (`ResourceTypes.LABELS`),
    rozdzielone „ · ”. Dla cudzej: `"gracz %d · szczegóły niewidoczne"`.
  - Lewa krawędź (`border_color` lokalnego `StyleBoxFlat` skopiowanego z motywu przez
    `get_theme_stylebox("panel").duplicate()`): `ATTACK` → `BLOOD` i `EtaBar` w wariacji
    `RaidBar`; `EXPEDITION` → `MOSS` i `ScoutBar`; pozostałe → `BRASS` i domyślny pasek.
  - Nieznana misja: ikona `fleet`, krawędź `BRASS`, tytuł z surowego klucza.
- Sygnał `tapped(fleet: Fleet)` z `gui_input` (`InputEventScreenTouch` puszczony).

### 8.2 `FleetsSheet`

```
FleetsSheet (PanelContainer, Sheet)                             FleetsSheet.gd
└── SheetMargin → VBoxContainer
    ├── Grabber
    ├── Header (ModalHeader): Icon "fleet" (CREAM) · Title "FLOTY" · CloseButton
    └── Scroll (ScrollContainer, EXPAND_FILL) → List (VBoxContainer, separacja 10 × SCALE)
        ├── IncomingHeader (SectionHeader, "NADCHODZĄCE · n")   gdy n > 0
        ├── FleetCard × n (cudze, sortowane po arrive_at rosnąco)
        ├── OwnHeader (SectionHeader, "W DRODZE · n")             gdy n > 0
        ├── FleetCard × n (własne, sortowane po arrive_at rosnąco)
        └── EmptyLabel (Caption, "Żadna flota nie jest w drodze.")  gdy obie listy puste
```

- `refresh()` przy otwarciu i po `fleets_updated`: buduje listę z `GameState.fleets`,
  pomijając `is_arrived(now)`. Karty odświeżane w `_process` co 1 s (akumulator), tylko gdy
  arkusz widoczny.
- `FleetCard.tapped` → `Sheets.close()` i `SceneManager.show_world_map_at(fleet.position_at(now))`.
- Sekcja „floty bezczynne” nie wchodzi.

## 9. Obsługa błędów

- Brak osady aktywnej: widok osady z pustym generatorem i „Brak osady”; HUD z kreskami;
  `Dock.MapButton` ukryty, dopóki `GameState.world == null`.
- Brak pliku fontu: błąd parsowania `MedievalTheme.gd` przez `preload`; bez fallbacku.
- `Sheets.open_building` dla budynku spoza `Biome.slots(settlement.biome)`: `push_error`,
  arkusz zamknięty.
- `Sheets.open_inspect` dla morza: `push_error`, arkusz zamknięty.
- `show_world_map_at` dla floty przybyłej: `position_at` clampuje do `to`.
- Nieznana misja floty: jak w 8.1.
- Nieznany `Icon.kind`: kółko z obrysem i jedno `push_warning`.
- Dotknięcie arkusza nie trafia do widoku (arkusze i backdrop `mouse_filter = STOP`);
  pozostały chrome ma `PASS` lub `IGNORE`, jak po ostatniej poprawce inputu.

## 10. Testy

- `test/core/time_util_test.gd`: `format_thousands` dla 0, 999, 1000, 12480, 9999999,
  10000000, −1500.
- `test/core/fleet_test.gd`: `MISSION_LABELS` i `MISSION_ICONS` mają wpis dla każdej misji.
- `test/core/buildings_test.gd` (nowy): `Buildings.ICONS` i `DESCRIPTIONS` dla każdego typu;
  `ResourceTypes.ICONS` dla każdego zasobu.
- `test/scenes/medieval_theme_test.gd` (nowy): `build()` zwraca `Theme`; każda wariacja
  z listy 4.2 istnieje (`has_type_variation` / `get_type_variation_base`); `default_font != null`;
  `SCALE > 0`.
- `test/scenes/icon_test.gd` (nowy): każdy `kind` z tabeli 4.3 rysuje bez `push_warning`
  (przez `_draw` wywołane po `add_child` i `await get_tree().process_frame`).
- `test/scenes/island_generator_test.gd`: `slot_at` trafia w środek każdej plakietki;
  punkt tuż za krawędzią plakietki nie trafia; przy `show_slots = false` brak `SlotPlaque`.
- `test/scenes/fleet_card_test.gd` (nowy): `refresh` dla własnej floty ustawia tytuł,
  skład i `EtaBar`; dla cudzej skład „szczegóły niewidoczne”; flota przybyła daje
  `progress = 1`; `ATTACK` daje krawędź `BLOOD`.
- `test/scenes/sheets_test.gd` (nowy): `open_inspect` na morzu nie otwiera; `open_fleets`
  potem `close` kończy na `visible = false` (po `await` tweena); `view_changed` zamyka;
  drugie otwarcie przy otwartym zostawia dokładnie jeden widoczny arkusz.
- `tools/smoke_probe.gd`: nowy przepływ. Start: widok osady, `Main.theme != null`, HUD
  pokazuje „Koralowa”. `MapButton` → mapa. Tap cudzej osady → `InspectSheet` widoczny;
  tap backdropu → zamknięty. Przeciągnięcie po otwartym arkuszu nie zmienia `camera.position`.
  Tap własnej osady → widok osady. Tap slotu Town Hall → `BuildingSheet` z „LV 1”.
  `FleetsButton` → `FleetsSheet` z trzema `FleetCard` (jedna w sekcji „NADCHODZĄCE”).
  Tap karty → mapa z kamerą przy pozycji floty.
- Ręcznie: 1080 × 1920 i landscape, safe area z notchem, pinch.

## 11. Co znika z repo

`scenes/ui/BuildingMenu.tscn`, `scenes/ui/BuildingMenu.gd`; `InfoPanel`, `BackButton`,
`BuildingMenu` z `IslandDetail.tscn`; `Background` z `IslandDetail.tscn` i `WorldMap.tscn`;
`HUD.BAR_HEIGHT`; sześciokątne sloty i `Area2D` z `IslandGenerator`; stałe `SLOT_SIZE`,
`SLOT_HIT`, `EMPTY_SLOT_FILL`, `EMPTY_SLOT_LINE`.

## 12. Kolejność implementacji

Praca w osobnym git worktree w `.worktree/` (katalog w `.gitignore`), na gałęzi odchodzącej
od `feat/client-skeleton`.

1. Fonty i licencje; `MedievalTheme.gd`; `Icon.gd`; stałe `ICONS`, `DESCRIPTIONS`,
   `MISSION_*`; `format_thousands`; testy z sekcji 10 dla tych elementów.
2. `SafeArea.gd`; `Main.tscn` z morzem, motywem i pustymi warstwami `Dock` i `Sheets`;
   usunięcie `Background` z widoków; smoke test przechodzi ze starym przepływem.
3. `HUD` w nowej szacie, `bar_height()`.
4. `SceneManager`: `map_camera_state`, `show_world_map_at`, fade, start w osadzie;
   `WorldMap.focus`, `MapCamera.zoom_by`.
5. `SlotPlaque`, zmiany w `IslandGenerator`, `IslandDetail` bez menu; `Sheets`
   z `BuildingSheet`; usunięcie `BuildingMenu`.
6. Warstwa UI mapy, kolory etykiet, tap → `InspectSheet`.
7. `Dock`, `FleetCard`, `FleetsSheet`.
8. Smoke test z nowym przepływem, testy scen, przegląd wobec projektu w edytorze.
