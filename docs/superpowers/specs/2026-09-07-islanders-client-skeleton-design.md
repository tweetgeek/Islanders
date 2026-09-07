# Islanders – szkielet klienta Godot 4 (PoC)

Data: 2026-09-07
Status: zatwierdzony w brainstormingu, czeka na plan implementacji

## 1. Cel

Klient mobilny (Godot 4.8, GDScript 2.0) dla procedural MMO RTS w scenerii archipelagu.
Ten spec obejmuje **szkielet PoC**: strukturę projektu, generator wysp, mapę świata
z kamerą, HUD z leniwym licznikiem zasobów oraz renderowanie mockowych flot.
Backend (NestJS w `../IslandersAPI`) jest pusty; klient definiuje kontrakt JSON,
a dane pochodzą z lokalnego mocka za wymiennym interfejsem providera.

Poza zakresem: rekrutacja i wysyłanie flot z UI, logika ulepszania budynków,
prawdziwe endpointy HTTP, walka, logowanie, grafika zewnętrzna.

## 2. Decyzje architektoniczne

| Decyzja | Wybór | Uzasadnienie |
|---|---|---|
| Stan gry | Centralny autoload `GameState` z typowanymi modelami `RefCounted` i sygnałami | Jedno źródło prawdy dla HUD, mapy i detalu; widoki nie komunikują się bezpośrednio |
| Geometria świata | Deterministyczna z `world_seed` + `(x, y)` po stronie klienta (`WorldGrid`) | Mapa renderuje się bez requestów; backend liczy to samo z tego samego seeda. Algorytm placementu trzeba zamrozić wcześnie |
| Dane | `ApiClient` → `ApiProvider` (interfejs) → `MockProvider` teraz, `HttpProvider` później | PoC działa out-of-the-box, wymiana providera nie dotyka reszty klienta |
| Orientacja | Portret główny (1080×1920), landscape wspierany przez anchors | Styl Tribal Wars na telefonie |
| Testy | gdUnit4, headless z CLI, tylko dla `scripts/core/` i providera | Czysta logika testowana, sceny weryfikowane ręcznie |
| Świat | Ograniczony, `WORLD_CELLS = 200×200` | Upraszcza backend; nieskończoność to zmiana jednej stałej |
| Grafika | Wyłącznie `Polygon2D`, `Line2D`, `ColorRect`, `Label`, `_draw()` | Brak zewnętrznych assetów |

## 3. Struktura projektu

```
res://
├── project.godot                  # autoloady, viewport 1080x1920, orientacja sensor
├── addons/gdUnit4/
├── scenes/
│   ├── autoload/
│   │   ├── ApiClient.gd           # fasada danych, Timer resync 60 s, server_time_offset
│   │   ├── SceneManager.gd        # przełączanie widoków w Main.tscn, sygnał view_changed
│   │   └── GameState.gd           # store: islands, fleets, world_seed, wind, sygnały
│   ├── views/
│   │   ├── Main.tscn              # root: ViewContainer + HUD
│   │   ├── WorldMap.tscn / .gd
│   │   ├── MapCamera.gd
│   │   └── IslandDetail.tscn / .gd
│   ├── procedural/
│   │   ├── IslandGenerator.gd     # Node2D @tool, rysuje wyspę
│   │   └── FleetRenderer.gd       # Node2D, _draw() tras i pozycji flot
│   └── ui/
│       ├── HUD.tscn / .gd
│       └── BuildingMenu.tscn / .gd
├── scripts/
│   ├── core/                      # czysta logika, zero Node, w pełni testowana
│   │   ├── IslandData.gd
│   │   ├── FleetData.gd
│   │   ├── Biome.gd
│   │   ├── WorldGrid.gd
│   │   ├── CoastlineGenerator.gd
│   │   ├── Navigation.gd
│   │   └── TimeUtil.gd
│   └── api/
│       ├── ApiProvider.gd         # klasa bazowa
│       ├── MockProvider.gd        # fixtures + relatywizacja czasów
│       └── HttpProvider.gd        # szkielet HTTPRequest, bez endpointów
├── fixtures/
│   ├── islands.json
│   └── fleets.json
└── test/
    ├── core/
    └── api/
```

Autoloady w kolejności: `GameState`, `ApiClient`, `SceneManager`.

Ustawienia `project.godot`:
- `display/window/size/viewport_width = 1080`, `viewport_height = 1920`
- `display/window/stretch/mode = canvas_items`, `aspect = expand` (istnieje)
- `display/window/handheld/orientation = sensor`
- `input_devices/pointing/emulate_touch_from_mouse = true`
- `input_devices/pointing/emulate_mouse_from_touch = false`
- Main scene: `res://scenes/views/Main.tscn`

Przepływ startu: `Main._ready()` → `ApiClient.load_initial()` → `GameState.apply_islands()` /
`apply_fleets()` → sygnał `islands_loaded` → `SceneManager.show_world_map()`.

## 4. Model danych i kontrakt JSON

### 4.1 Wyspa

```json
{
  "id": 1, "x": 10, "y": 15, "seed": 84920, "biome": "TROPICAL",
  "ownerId": 7, "name": "Koralowa",
  "resources": { "wood": 500, "stone": 200, "food": 1000 },
  "population": 42, "populationMax": 120,
  "productionPerHour": { "wood": 120, "stone": 60, "food": 200 },
  "buildings": { "TOWN_HALL": 1, "SAWMILL": 2, "QUARRY": 1, "BARRACKS": 0, "SHIPYARD": 0 },
  "lastSyncAt": "2026-09-07T12:00:00Z"
}
```

### 4.2 Flota

```json
{
  "id": 3, "ownerId": 7, "fromIslandId": 1, "toIslandId": 5,
  "from": {"x": 10, "y": 15}, "to": {"x": 14, "y": 9},
  "ships": 12, "departAt": "2026-09-07T12:00:00Z", "arriveAt": "2026-09-07T12:40:00Z"
}
```

### 4.3 Zasady

- `productionPerHour` przychodzi z serwera. Klient nie wylicza go z poziomów budynków.
  `Biome.base_production` służy tylko mockowi i placeholderom.
- Czas: ISO 8601 UTC. `IslandData.current_resources(now_unix: float) -> Dictionary`
  liczy `clamp(stored + rate * (now - last_sync) / 3600, 0, STORAGE_CAP)`.
  `STORAGE_CAP = 10000` jako stała w `Biome.gd` (później z serwera).
  `now` zawsze jako argument, nigdy pobierany wewnątrz modelu.
- `GameState`: `islands: Dictionary` (id → `IslandData`), `fleets: Dictionary`,
  `player_id: int`, `home_island_id: int`, `world_seed: int`, `wind: Vector2`,
  `selected_island_id: int`. Sygnały: `islands_loaded`, `island_updated(id)`,
  `fleets_updated`, `island_selected(id)`. Mutacje wyłącznie przez
  `apply_islands(Array)`, `apply_fleets(Array)`, `select_island(id)`.
- Biomy: `TROPICAL`, `TEMPERATE`, `VOLCANIC`. Nieznany string → `TEMPERATE` + `push_warning`.
- Współrzędne `(x, y)` to komórki siatki (`Vector2i`). `WorldGrid.CELL_SIZE = 256.0` px,
  wyspa w środku komórki.
- Wyspa bez stanu z serwera (placeholder z siatki) dostaje w `GameState` id tymczasowe
  `-abs(hash)` i `IslandData` z `Biome.base_production`, `ownerId = 0`, `lastSyncAt = now`.

### 4.4 Sygnały między warstwami

- HUD słucha `island_selected`, `island_updated`.
- WorldMap słucha `islands_loaded`, `fleets_updated`.
- Widoki nie wołają siebie nawzajem; nawigacja wyłącznie przez `SceneManager`.

## 5. Generator wysp

### 5.1 `CoastlineGenerator.gd` (statyczna, testowana)

`static func generate(seed_val: int, radius: float, points: int = 48, roughness: float = 0.35) -> PackedVector2Array`

- Dla `i in 0..points-1`: `θ = i / points * TAU`. Szum 2D próbkowany na okręgu:
  `n = noise.get_noise_2d(cos(θ) * f, sin(θ) * f)`; próbkowanie po okręgu gwarantuje
  zamknięcie konturu bez szwu.
- `r = radius * (1 + roughness * n)`, punkt `= Vector2(cos θ, sin θ * ellipse) * r`,
  gdzie `ellipse = 0.8 + 0.4 * hash01(seed_val)`.
- `FastNoiseLite`: `seed = seed_val`, `TYPE_SIMPLEX_SMOOTH`, `fractal_octaves = 3`.
- Gwarancje (testy): determinizm, liczba punktów, promienie w
  `[radius*(1-roughness), radius*(1+roughness)]` (przed skalowaniem elipsą),
  `Geometry2D.triangulate_polygon` niepuste dla `roughness ≤ 0.4`.

### 5.2 `IslandGenerator.gd` (`Node2D`, `@tool`)

Eksporty: `seed_val: int`, `radius: float = 96.0`, `biome: Biome.Type`, `show_slots: bool`.
`build()` czyści dzieci i rysuje warstwy od spodu:

1. `Polygon2D` shallow water: kontur ×1.18, półprzezroczysty jasny błękit.
2. `Polygon2D` sand: kontur ×1.0, kolor piasku biomu.
3. `Polygon2D` land: kontur ×0.78, ten sam seed, `roughness = 0.25`, kolor lądu biomu.
   `VOLCANIC`: dodatkowo mały ciemnoczerwony `Polygon2D` w centrum (krater).
4. `Line2D` coastline: kontur ×1.0 domknięty, `width = 3`, `joint_mode = ROUND`,
   ciemniejszy odcień piasku.
5. Sloty (tylko gdy `show_slots`): 5 × `Node2D` z `Polygon2D` (sześciokąt), `Label`,
   `Area2D`. Town Hall w centrum, Sawmill/Quarry/Barracks/Shipyard na okręgu
   `radius * 0.45` co 90°, Shipyard w kierunku najmniejszego promienia konturu.
   Pusty slot = szary obrys, zajęty = wypełnienie kolorem biomu + poziom w labelu.
   Sygnał `slot_tapped(building_type: String)`.

`Biome.gd`: `enum Type`, tabela `{ land, sand, coast, crater }: Color`,
`base_production: Dictionary`, `STORAGE_CAP`.

## 6. Mapa świata i kamera

### 6.1 `WorldGrid.gd` (statyczna, testowana)

- `CELL_SIZE = 256.0`, `CHUNK_SIZE = 8`, `WORLD_CELLS = Vector2i(200, 200)`.
- `static func island_at(world_seed: int, cell: Vector2i) -> Dictionary`:
  `{}` dla morza albo `{ seed, radius, biome }`. Istnienie: `FastNoiseLite`
  (seed = `world_seed`) na współrzędnych komórki z progiem dającym 10–25 % zajętości.
  Seed wyspy = `hash([world_seed, x, y])`. Biom z drugiego szumu o dużej skali
  (regiony). Promień 60–110 px z hasha.
- `cell_to_world`, `world_to_cell`, `chunk_of`.
- Dane z `GameState` nadpisują placeholder (seed i biom z serwera mają pierwszeństwo).

### 6.2 `WorldMap.tscn`

```
WorldMap (Node2D)
├── Water (Node2D)        # _draw(): linie siatki co CELL_SIZE w widocznym rect
├── Chunks (Node2D)       # kontenery per chunk z IslandGenerator (show_slots = false)
├── Fleets (FleetRenderer)
└── Camera (Camera2D)     # MapCamera.gd
```

Tło morza: `ColorRect` w `CanvasLayer` z `layer = -100`.

Chunkowanie: co 0,2 s liczymy chunki rogów widocznego prostokąta (+1 chunk marginesu).
Nowe → spawn, maks. 2 chunki na klatkę. Poza zasięgiem → `queue_free`.
`loaded_chunks: Dictionary` (Vector2i → Node2D). Kamera clampowana do granic świata.

### 6.3 `MapCamera.gd`

- Pan: `InputEventScreenDrag` (jeden palec) lub `InputEventMouseMotion` z LPM.
  Przesunięcie dzielone przez `zoom`. Inercja po puszczeniu, wygaszana `lerp`.
- Pinch: dwa dotyki w `touches: Dictionary` (index → pozycja). Zmiana dystansu →
  `zoom` w `[0.25, 2.0]`, zoom wokół środka między palcami. Desktop: scroll → zoom do kursora.
- Tap: puszczenie po `< 250 ms` i przesunięciu `< 12 px`. Sygnał `tapped(world_pos: Vector2)`.
  Kamera nie zna wysp.

### 6.4 Tap na wyspie

`WorldMap` łączy `tapped` → `world_to_cell` → sprawdza wyspę w komórce i odległość
`≤ radius * 1.1` od środka. Trafienie → `GameState.select_island(id)` →
`SceneManager.show_island_detail()`. Brak `Area2D` na mapie.

### 6.5 `IslandDetail.tscn`

`Node2D` z jednym `IslandGenerator` (`radius = 400`, `show_slots = true`), własna
`Camera2D` bez panu, przycisk „← Mapa” (`Control`, anchor top-left, pod HUD).
`slot_tapped` → `BuildingMenu.open(building_type, level)`. Menu: nazwa, poziom,
przycisk „Ulepsz” emitujący `upgrade_requested(building_type)` (bez logiki).

## 7. HUD i lazy resources

```
HUD (CanvasLayer, layer 10)
└── TopBar (PanelContainer, anchor top-wide, 96 px, offset o safe area)
    └── HBox
        ├── ResourceChip ×4 (Wood, Stone, Food, Population): ColorRect 24×24 + Label
        └── IslandName (Label): nazwa + (x, y)
```

- Chipy `size_flags_horizontal = EXPAND_FILL`. Poniżej 700 px szerokości viewportu
  labele używają `TimeUtil.format_amount` (`1.2k`).
- HUD trzyma `_island: IslandData` (z `GameState` po `island_selected` / `island_updated`).
  W `_process` co klatkę: `_island.current_resources(TimeUtil.now())` → `floor()` → labele.
  Populacja stała: `42 / 120`.
- Brak wybranej wyspy → HUD pokazuje `GameState.home_island_id`.
- `ApiClient` ma `Timer` 60 s wołający providera ponownie; `apply_islands` nadpisuje
  `resources` i `lastSyncAt`. `MockProvider` przy odświeżeniu przelicza zasoby na „teraz”
  i ustawia `lastSyncAt = now`, tak jak zrobi prawdziwy backend.
- `TimeUtil.now()` = `Time.get_unix_time_from_system() + ApiClient.server_time_offset`.
  Nic poza `TimeUtil` nie woła `Time` bezpośrednio.

## 8. Floty i nawigacja

### 8.1 `Navigation.gd` (statyczna, testowana)

- `distance(from: Vector2i, to: Vector2i) -> float`: euklidesowa w komórkach.
- `travel_time(from, to, speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float`
  w sekundach. `effective = speed * clamp(1 + WIND_FACTOR * wind.dot(direction), 0.5, 1.5)`,
  `WIND_FACTOR = 0.5`. Dystans 0 → 0 s.

### 8.2 `FleetData.gd`

`from_json`, `progress(now) -> float` (clamp 0..1), `position_at(now) -> Vector2`
(lerp w pikselach przez `WorldGrid.cell_to_world`), `is_arrived(now) -> bool`.
`arriveAt` pochodzi z serwera i nie jest przeliczany na kliencie.

### 8.3 `FleetRenderer.gd`

`_draw()` dla każdej floty z `GameState.fleets`: linia przerywana `from → to`
(własne żółte, obce czerwone), trójkąt w `position_at(now)` obrócony w kierunku ruchu,
`draw_string` z pozostałym czasem `mm:ss`. `queue_redraw()` co klatkę. Floty
`is_arrived` pomijane w rysowaniu; usuwanie z modelu należy do serwera.

Mock: 2 floty (własna w trakcie: depart = now − 10 min, arrive = now + 30 min; obca).
`MockProvider` relatywizuje czasy względem `now` przy ładowaniu.

## 9. Warstwa API

- `ApiProvider` (klasa bazowa): `fetch_islands() -> Array`, `fetch_fleets() -> Array`,
  `fetch_world() -> Dictionary` (`{ worldSeed, playerId, homeIslandId, wind }`).
  Metody asynchroniczne (`await`), zwracają sparsowane struktury.
- `MockProvider`: czyta `fixtures/*.json`, relatywizuje czasy, przelicza zasoby.
  Fixtures leżą w komórkach uznanych przez `WorldGrid` za ląd (test).
- `HttpProvider`: `HTTPRequest`, `base_url` z ustawienia projektu, parsowanie JSON,
  odczyt nagłówka `Date` do `server_time_offset`. Bez działających endpointów.
- `ApiClient`: wybiera providera przez `ProjectSettings` `islanders/api/use_mock` (domyślnie true).

## 10. Obsługa błędów

- Nieudany fetch (`HttpProvider`): `push_error`, sygnał `ApiClient.request_failed(reason)`,
  brak zmian w `GameState`. HUD nadal ekstrapoluje z ostatniego syncu.
- Niepoprawny JSON / brakujące pole: `from_json` używa wartości domyślnych i `push_warning`;
  brak `id` lub `seed` odrzuca rekord.
- Nieznany biom → `TEMPERATE`. Nieznany typ budynku ignorowany.
- Tap poza wyspą: bez akcji.

## 11. Testy i weryfikacja

- gdUnit4 w `addons/`, uruchamiane headless z CLI (komenda do potwierdzenia po instalacji,
  docelowo `Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/`).
- `test/core/`: `CoastlineGenerator` (determinizm, liczba punktów, zakres promieni,
  triangulacja), `WorldGrid` (determinizm, gęstość 10–25 % na próbce 100×100,
  odwracalność cell↔world), `IslandData` (`from_json` pełny/braki, `current_resources`
  0 h / 2 h / cap / ujemny delta), `FleetData` (`progress` przed/w trakcie/po),
  `Navigation` (zero, wiatr w plecy, pod wiatr, prostopadły, clamp), `TimeUtil`
  (ISO 8601 z `Z` i z offsetem, `format_amount`).
- `test/api/`: `MockProvider` zwraca poprawne struktury; fixtures na lądzie wg `WorldGrid`.
- Smoke test: `Godot --headless --path . --quit` kończy się bez błędów skryptów.
- Ręcznie w edytorze: pan, pinch (emulacja z myszy), tap → detail → powrót, HUD rośnie.
- Ryzyko: Godot 4.8 dev4 to build deweloperski. Jeśli gdUnit4 nie działa, wracamy do
  użytkownika z opcją własnych skryptów testowych.

## 12. Kolejność implementacji

1. `project.godot`, struktura katalogów, gdUnit4, smoke test.
2. `scripts/core/`: `TimeUtil`, `Biome`, `IslandData`, `FleetData` z testami.
3. `CoastlineGenerator` + testy, `IslandGenerator` (podgląd w edytorze).
4. `WorldGrid` + testy, `Navigation` + testy.
5. Warstwa API: `ApiProvider`, `MockProvider` + fixtures + testy, `HttpProvider` szkielet.
6. Autoloady: `GameState`, `ApiClient`, `SceneManager`; `Main.tscn`.
7. `WorldMap` + `MapCamera` + chunkowanie + tap.
8. `IslandDetail` + `BuildingMenu`.
9. `HUD` z lazy resources.
10. `FleetRenderer`.
