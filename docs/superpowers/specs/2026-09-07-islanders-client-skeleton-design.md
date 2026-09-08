# Islanders – szkielet klienta Godot 4 (PoC)

Data: 2026-09-07
Status: zatwierdzony w brainstormingu, uzupełniony po sesji modelowania domeny (`CONTEXT.md`, ADR 0001, 0002), czeka na plan implementacji

Terminologia w tym dokumencie jest zgodna z `CONTEXT.md`. Jeśli termin tu i tam się różni, glosariusz ma pierwszeństwo.

## 1. Cel

Klient mobilny (Godot 4.8, GDScript 2.0) dla procedural MMO RTS w scenerii archipelagu.
Ten spec obejmuje **szkielet PoC**: strukturę projektu, generator wysp, mapę świata
z kamerą, HUD z leniwym licznikiem zasobów oraz renderowanie mockowych flot.
Backend (NestJS w `../IslandersAPI`) jest pusty; klient definiuje kontrakt JSON,
a dane pochodzą z lokalnego mocka za wymiennym interfejsem providera.

Poza zakresem: rekrutacja i wysyłanie flot z UI, logika ulepszania budynków,
wyprawy i kolonizacja jako akcje, prawdziwe endpointy HTTP, walka, logowanie,
grafika zewnętrzna.

## 2. Decyzje architektoniczne

| Decyzja | Wybór | Uzasadnienie |
|---|---|---|
| Stan gry | Centralny autoload `GameState` z typowanymi modelami `RefCounted` i sygnałami | Jedno źródło prawdy dla HUD, mapy i detalu; widoki nie komunikują się bezpośrednio |
| Geometria świata | Deterministyczna z `worldSeed` + `(x, y)` po stronie klienta (`WorldGrid`), tożsamość wyspy `(worldId, x, y)` | ADR 0001 |
| Zasoby | Pięć zasobów, każdy produkowany tylko w biomach, do których należy | ADR 0002 |
| Dane | `ApiClient` → `ApiProvider` (interfejs) → `MockProvider` teraz, `HttpProvider` później | PoC działa out-of-the-box, wymiana providera nie dotyka reszty klienta |
| Orientacja | Portret główny (1080×1920), landscape wspierany przez anchors | Styl Tribal Wars na telefonie |
| Testy | gdUnit4, headless z CLI, tylko dla `scripts/core/` i providera | Czysta logika testowana, sceny weryfikowane ręcznie |
| Świat | Ograniczony, `WORLD_CELLS = 200×200`, wiele światów w modelu, jeden w mocku | Upraszcza backend; nieskończoność to zmiana jednej stałej |
| Grafika | Wyłącznie `Polygon2D`, `Line2D`, `ColorRect`, `Label`, `_draw()` | Brak zewnętrznych assetów |

## 3. Struktura projektu

```
res://
├── project.godot                  # autoloady, viewport 1080x1920, orientacja sensor
├── addons/gdUnit4/
├── scenes/
│   ├── autoload/
│   │   ├── ApiClient.gd           # fasada danych, Timer resync 60 s
│   │   ├── SceneManager.gd        # przełączanie widoków w Main.tscn, sygnał view_changed
│   │   └── GameState.gd           # store: world, settlements, fleets, active/inspected
│   ├── views/
│   │   ├── Main.tscn              # root: ViewContainer + HUD
│   │   ├── WorldMap.tscn / .gd
│   │   ├── MapCamera.gd
│   │   ├── Water.gd               # Node2D, _draw() siatki wody widocznego obszaru
│   │   └── IslandDetail.tscn / .gd
│   ├── procedural/
│   │   ├── IslandGenerator.gd     # Node2D @tool, rysuje wyspę i sloty
│   │   └── FleetRenderer.gd       # Node2D, _draw() tras i pozycji flot
│   └── ui/
│       ├── HUD.tscn / .gd
│       └── BuildingMenu.tscn / .gd
├── scripts/
│   ├── core/                      # czysta logika, zero Node, w pełni testowana
│   │   ├── Coord.gd               # Vector2i helpers, klucz "x:y"
│   │   ├── Biome.gd               # enum, kolory, zasoby biomu, sloty wydobywcze
│   │   ├── ResourceTypes.gd       # enum zasobów, nazwy, kolory chipów
│   │   ├── Buildings.gd           # enum budynków, sloty wspólne
│   │   ├── Island.gd              # geografia: coord, seed, biome, radius, deposit
│   │   ├── Settlement.gd          # stan: owner, name, resources, buildings, population, capacity
│   │   ├── Fleet.gd               # from, to, mission, ships, cargo, departAt, arriveAt
│   │   ├── GameWorld.gd           # id, seed, size, wind, status
│   │   ├── WorldGrid.gd           # deterministyczny placement wysp w chunkach
│   │   ├── CoastlineGenerator.gd  # sam kontur PackedVector2Array
│   │   ├── SeaNavigation.gd       # travel_time(from, to, speed, wind)
│   │   └── TimeUtil.gd            # parse ISO8601, now(), format_amount
│   └── api/
│       ├── ApiProvider.gd         # klasa bazowa
│       ├── MockProvider.gd        # fixtures + relatywizacja czasów
│       └── HttpProvider.gd        # szkielet HTTPRequest, bez endpointów
├── fixtures/
│   ├── world.json
│   ├── settlements.json
│   └── fleets.json
└── test/
    ├── core/
    └── api/
```

`Resources.gd`, `World.gd` i `Navigation.gd` z pierwotnego planu nazywają się w kodzie
`ResourceTypes.gd`, `GameWorld.gd` i `SeaNavigation.gd` — te trzy nazwy kolidowałyby
z wbudowanymi klasami silnika Godota, więc zostały przemianowane.

Autoloady w kolejności: `GameState`, `ApiClient`, `SceneManager`.

Ustawienia `project.godot`:
- `display/window/size/viewport_width = 1080`, `viewport_height = 1920`
- `display/window/stretch/mode = canvas_items`, `aspect = expand` (istnieje)
- `display/window/handheld/orientation = sensor`
- `input_devices/pointing/emulate_touch_from_mouse = true`
- `input_devices/pointing/emulate_mouse_from_touch = false`
- Main scene: `res://scenes/views/Main.tscn`

Przepływ startu: `Main._ready()` → `ApiClient.load_initial()` → `GameState.apply_world()`,
`apply_settlements()`, `apply_fleets()` → sygnał `state_loaded` → `SceneManager.show_world_map()`.

## 4. Model danych i kontrakt JSON

### 4.1 World

```json
{
  "id": "w1", "seed": 1337, "size": { "w": 200, "h": 200 },
  "wind": { "x": 0.3, "y": -0.1 }, "status": "OPEN",
  "playerId": 7, "homeSettlement": { "x": 10, "y": 15 },
  "serverTime": "2026-09-07T12:00:00Z"
}
```

`playerId` i `homeSettlement` to dane sesji gracza na tym świecie; w prawdziwym API
wrócą z endpointu sesji, w mocku siedzą tu dla prostoty.

### 4.2 Settlement

```json
{
  "world": "w1", "x": 10, "y": 15,
  "ownerId": 7, "name": "Koralowa",
  "resources": { "wood": 500, "stone": 200, "food": 1000, "iron": 40, "sulfur": 0 },
  "productionPerHour": { "wood": 120, "stone": 0, "food": 200, "iron": 0, "sulfur": 0 },
  "capacity": 8000,
  "population": 42, "populationMax": 120,
  "buildings": { "TOWN_HALL": 1, "BARRACKS": 0, "SHIPYARD": 1, "WAREHOUSE": 1, "SAWMILL": 2, "FARM": 1 },
  "lastSyncAt": "2026-09-07T12:00:00Z"
}
```

Cudza osada (dane publiczne) ma tylko `world`, `x`, `y`, `ownerId`, `name`.
Brak `resources` w JSON oznacza osadę cudzą; klient rozróżnia to przez `Settlement.is_own`.

### 4.3 Fleet

```json
{
  "id": "f3", "world": "w1", "ownerId": 7, "mission": "EXPEDITION",
  "from": { "x": 10, "y": 15 }, "to": { "x": 14, "y": 9 },
  "ships": { "SLOOP": 10, "GALLEON": 2 },
  "cargo": { "units": { "MILITIA": 20 }, "resources": { "iron": 300 } },
  "departAt": "2026-09-07T12:00:00Z", "arriveAt": "2026-09-07T12:40:00Z"
}
```

Flota ma własne `id`, bo między tymi samymi wyspami może lecieć wiele flot.
Nadchodząca cudza flota ma `ownerId`, `mission`, `from`, `to`, `arriveAt`, bez `ships` i `cargo`.

### 4.4 Island (nie przychodzi z API)

`Island` powstaje wyłącznie z `WorldGrid.island_at(world_seed, coord)`:
`coord: Vector2i`, `seed: int`, `biome: Biome.Type`, `radius: float`,
`deposit: Dictionary` (zasób → ilość, pusty gdy brak znaleziska).

### 4.5 Zasady

- Zasoby: `Resources.Type = { WOOD, STONE, FOOD, IRON, SULFUR }`. Biomy: `TROPICAL`
  (wood, food), `TEMPERATE` (stone, food), `VOLCANIC` (iron, sulfur). Nieznany biom →
  `TEMPERATE` + `push_warning`.
- `productionPerHour` i `capacity` przychodzą z serwera. Klient nie wylicza ich z poziomów.
- Czas: ISO 8601 UTC. `Settlement.current_resources(now_unix: float) -> Dictionary`
  liczy `clamp(stored + rate * (now - last_sync) / 3600, 0, capacity)` dla każdego zasobu.
  `now` zawsze jako argument.
- Budynki: `Buildings.COMMON = [TOWN_HALL, BARRACKS, SHIPYARD, WAREHOUSE]`,
  `Biome.extraction_buildings(biome) -> Array` zwraca dwa budynki wydobywcze.
  Sloty osady = wspólne + wydobywcze biomu, zawsze 6. Brakujący klucz w `buildings` = poziom 0.
  Klucz budynku spoza slotów biomu → `push_warning`, ignorowany.
- Współrzędne: `Vector2i` w komórkach. `Coord.key(v) -> String` (`"10:15"`) jako klucz słowników.
  `WorldGrid.CELL_SIZE = 256.0` px, wyspa w środku komórki.
- Deposit istnieje tylko na wyspach bez osady. Gdy `GameState` ma osadę pod współrzędnymi
  wyspy, mapa nie rysuje znacznika znaleziska.

### 4.6 GameState

Pola: `world: World`, `player_id: int`, `settlements: Dictionary` (klucz `Coord.key` → `Settlement`),
`fleets: Dictionary` (id → `Fleet`), `active_settlement: Settlement`,
`inspected_coord: Vector2i` (albo `Coord.NONE`).

Sygnały: `state_loaded`, `settlement_updated(coord: Vector2i)`, `fleets_updated`,
`active_settlement_changed`, `inspected_island_changed(coord: Vector2i)`.

Mutacje wyłącznie przez `apply_world(Dictionary)`, `apply_settlements(Array)`,
`apply_fleets(Array)`, `set_active_settlement(coord)`, `inspect(coord)`.
`set_active_settlement` odrzuca osadę cudzą (`push_error`, brak zmiany).
Przy `state_loaded` osadą aktywną staje się osada domowa.

Pomocnicze: `settlement_at(coord) -> Settlement` (albo `null`), `own_settlements() -> Array`.

### 4.7 Sygnały między warstwami

- HUD słucha `active_settlement_changed`, `settlement_updated`.
- WorldMap nie słucha `state_loaded` — `SceneManager` tworzy jej scenę dopiero po
  zakończeniu ładowania, więc `_ready()` czyta stan od razu z `GameState` bezpośrednio;
  później słucha `fleets_updated`, `settlement_updated`.
- IslandDetail słucha `inspected_island_changed`.
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

Eksporty: `seed_val: int`, `radius: float = 96.0`, `biome: Biome.Type`, `show_slots: bool`,
`show_deposit: bool`. Metoda `set_settlement(s: Settlement)` (może być `null`) ustawia
poziomy slotów. `build()` czyści dzieci i rysuje warstwy od spodu:

1. `Polygon2D` shallow water: kontur ×1.18, półprzezroczysty jasny błękit.
2. `Polygon2D` sand: kontur ×1.0, kolor piasku biomu.
3. `Polygon2D` land: kontur ×0.78, ten sam seed, `roughness = 0.25`, kolor lądu biomu.
   `VOLCANIC`: dodatkowo mały ciemnoczerwony `Polygon2D` w centrum (krater).
4. `Line2D` coastline: kontur ×1.0 domknięty, `width = 3`, `joint_mode = ROUND`,
   ciemniejszy odcień piasku.
5. Znacznik znaleziska (gdy `show_deposit` i wyspa ma deposit): mały `Polygon2D`
   (romb) przy brzegu w kolorze dominującego zasobu znaleziska.
6. Sloty (tylko gdy `show_slots`): 6 × `Node2D` z `Polygon2D` (sześciokąt), `Label`,
   `Area2D`. Town Hall w centrum, pozostałe 5 na okręgu `radius * 0.45` co 72°,
   Shipyard w kierunku najmniejszego promienia konturu. Typy dwóch slotów wydobywczych
   z `Biome.extraction_buildings`. Poziom 0 = szary obrys, poziom > 0 = wypełnienie
   kolorem biomu + poziom w labelu. Sygnał `slot_tapped(building: Buildings.Type)`.

`Biome.gd`: `enum Type`, tabela `{ land, sand, coast, crater }: Color`,
`resources(biome) -> Array`, `extraction_buildings(biome) -> Array`.

## 6. Mapa świata i kamera

### 6.1 `WorldGrid.gd` (statyczna, testowana)

- `CELL_SIZE = 256.0`, `CHUNK_SIZE = 8`.
- `static func island_at(world_seed: int, cell: Vector2i) -> Island` (albo `null` dla morza).
  Istnienie: `FastNoiseLite` (seed = `world_seed`) na współrzędnych komórki z progiem
  dającym 10–25 % zajętości. Seed wyspy = `hash([world_seed, x, y])`. Biom z drugiego
  szumu o dużej skali (regiony). Promień 60–110 px z hasha. Deposit: trzeci hash decyduje,
  czy jest (ok. 30 % wysp), i losuje 1–2 zasoby **spoza biomu wyspy** (ADR 0002) z ilością.
- `cell_to_world`, `world_to_cell`, `chunk_of`, `in_bounds(cell, world_size)`.
- Osada z `GameState` nie zmienia geografii; nakłada tylko stan (sloty, brak znaleziska).

### 6.2 `WorldMap.tscn`

```
WorldMap (Node2D)
├── Water (Node2D)        # _draw(): linie siatki co CELL_SIZE w widocznym rect
├── Chunks (Node2D)       # kontenery per chunk z IslandGenerator (show_slots = false, show_deposit = true)
├── Labels (Node2D)       # nazwy osad + właściciel nad wyspami z osadą (widoczne przy zoom ≥ 0.6)
├── Fleets (FleetRenderer)
└── Camera (Camera2D)     # MapCamera.gd
```

Tło morza: `ColorRect` w `CanvasLayer` z `layer = -100`.

Chunkowanie: co 0,2 s liczymy chunki rogów widocznego prostokąta (+1 chunk marginesu).
Nowe → spawn, maks. 2 chunki na klatkę. Poza zasięgiem → `queue_free`.
`loaded_chunks: Dictionary` (Vector2i → Node2D). Kamera clampowana do granic `world.size`.
Własne osady mają obrys `Line2D` w kolorze gracza, cudze w kolorze neutralnym.

### 6.3 `MapCamera.gd`

- Pan: `InputEventScreenDrag` (jeden palec) lub `InputEventMouseMotion` z LPM.
  Przesunięcie dzielone przez `zoom`. Inercja po puszczeniu, wygaszana `lerp`.
- Pinch: dwa dotyki w `touches: Dictionary` (index → pozycja). Zmiana dystansu →
  `zoom` w `[0.25, 2.0]`, zoom wokół środka między palcami. Desktop: scroll → zoom do kursora.
- Tap: puszczenie po `< 250 ms` i przesunięciu `< 12 px`. Sygnał `tapped(world_pos: Vector2)`.
  Kamera nie zna wysp.

### 6.4 Tap na wyspie

`WorldMap` łączy `tapped` → `world_to_cell` → `WorldGrid.island_at` i odległość
`≤ radius * 1.1` od środka. Trafienie → `GameState.inspect(coord)` →
`SceneManager.show_island_detail()`. Jeśli pod współrzędnymi jest własna osada, dodatkowo
`GameState.set_active_settlement(coord)`. Brak `Area2D` na mapie.

### 6.5 `IslandDetail.tscn`

`Node2D` z jednym `IslandGenerator` (`radius = 400`, `show_slots` zależnie od stanu),
własna `Camera2D` bez panu, przycisk „← Mapa” (`Control`, anchor top-left, pod HUD).
Trzy tryby wg `GameState.settlement_at(inspected_coord)`:
- własna osada: sloty z poziomami, `slot_tapped` → `BuildingMenu.open(building, level)`;
- cudza osada: bez slotów, panel z nazwą i właścicielem;
- wyspa niczyja: bez slotów, panel z biomem i zawartością znaleziska.

`BuildingMenu`: nazwa, poziom, przycisk „Ulepsz” emitujący `upgrade_requested(building)` (bez logiki).

## 7. HUD i lazy resources

```
HUD (CanvasLayer, layer 10)
└── TopBar (PanelContainer, anchor top-wide, 96 px, offset o safe area)
    └── HBox
        ├── ResourceChip ×5 (wood, stone, food, iron, sulfur): ColorRect 24×24 + Label
        ├── PopulationChip: Label "42 / 120"
        └── SettlementName (Label): nazwa osady aktywnej + (x, y)
```

- Chipy `size_flags_horizontal = EXPAND_FILL`. Poniżej 700 px szerokości viewportu
  labele używają `TimeUtil.format_amount` (`1.2k`). Zasób, którego osada nie produkuje,
  ma chip przyciemniony (wciąż pokazuje stan magazynu).
- HUD trzyma `_settlement: Settlement` (z `GameState.active_settlement` po
  `active_settlement_changed` / `settlement_updated`). W `_process` co klatkę:
  `_settlement.current_resources(TimeUtil.now())` → `floor()` → labele.
- HUD nigdy nie pokazuje osady cudzej ani oglądanej wyspy; to zadanie `IslandDetail`.
- `ApiClient` ma `Timer` 60 s wołający providera ponownie; `apply_settlements` nadpisuje
  `resources` i `lastSyncAt`. `MockProvider` przy odświeżeniu przelicza zasoby na „teraz”
  i ustawia `lastSyncAt = now`, tak jak zrobi prawdziwy backend.
- `TimeUtil.now()` = `Time.get_unix_time_from_system() + TimeUtil.server_time_offset`. Offset,
  ustawiany przez `TimeUtil.set_server_time()`, liczony jest z `serverTime` w odpowiedzi `world`.
  Offset mieszka w `TimeUtil`, nie w `ApiClient` — dzięki temu `scripts/core/` (gdzie żyje
  `TimeUtil`) nie zależy od żadnego autoloadu, co jest tą samą warstwową zasadą, której ten
  spec wymaga od reszty `scripts/core/`. Nic poza `TimeUtil` nie woła `Time` bezpośrednio.

## 8. Floty i nawigacja

### 8.1 `SeaNavigation.gd` (statyczna, testowana)

- `distance(from: Vector2i, to: Vector2i) -> float`: euklidesowa w komórkach.
- `travel_time(from, to, speed_cells_per_hour: float, wind: Vector2 = Vector2.ZERO) -> float`
  w sekundach. `effective = speed * clamp(1 + WIND_FACTOR * wind.dot(direction), 0.5, 1.5)`,
  `WIND_FACTOR = 0.5`. Dystans 0 → 0 s.
- `fleet_speed(ships: Dictionary) -> float`: prędkość najwolniejszego typu z tabeli
  `Ships.SPEED` (`SLOOP: 8`, `GALLEON: 4` komórek/h; tabela w `Fleet.gd` do czasu, aż
  będzie więcej typów).

### 8.2 `Fleet.gd`

`from_json`, `progress(now) -> float` (clamp 0..1), `position_at(now) -> Vector2`
(lerp w pikselach przez `WorldGrid.cell_to_world`), `is_arrived(now) -> bool`,
`is_own(player_id) -> bool`, `total_ships() -> int`. `arriveAt` pochodzi z serwera i nie
jest przeliczany na kliencie.

### 8.3 `FleetRenderer.gd`

`_draw()` dla każdej floty z `GameState.fleets`: linia przerywana `from → to`
(własne żółte, nadchodzące czerwone), trójkąt w `position_at(now)` obrócony w kierunku ruchu,
`draw_string` z pozostałym czasem `mm:ss` i skrótem misji. `queue_redraw()` co klatkę.
Floty `is_arrived` pomijane w rysowaniu; usuwanie z modelu należy do serwera.

Mock: 3 floty: własna `EXPEDITION` w trakcie (depart = now − 10 min, arrive = now + 30 min),
własna `RETURN`, nadchodząca cudza `ATTACK` na osadę domową (arrive = now + 2 h).
`MockProvider` relatywizuje czasy względem `now` przy ładowaniu.

## 9. Warstwa API

- `ApiProvider` (klasa bazowa): `fetch_world() -> Dictionary`, `fetch_settlements() -> Array`
  (własne osady w pełni, cudze w widocznym obszarze jako dane publiczne; w mocku wszystkie),
  `fetch_fleets() -> Array` (własne + nadchodzące). Metody asynchroniczne (`await`).
- `MockProvider`: czyta `fixtures/*.json`, relatywizuje czasy, przelicza zasoby.
  Fixtures leżą w komórkach uznanych przez `WorldGrid` za ląd, a budynki wydobywcze
  w fixtures pasują do biomu wyspy (oba sprawdzane testem).
- `HttpProvider`: `HTTPRequest`, `base_url` z ustawienia projektu, parsowanie JSON,
  `serverTime` do `TimeUtil.server_time_offset` (przez `TimeUtil.set_server_time()`).
  Bez działających endpointów.
- `ApiClient`: wybiera providera przez `ProjectSettings` `islanders/api/use_mock` (domyślnie true).

## 10. Obsługa błędów

- Nieudany fetch (`HttpProvider`): `push_error`, sygnał `ApiClient.request_failed(reason)`,
  brak zmian w `GameState`. HUD nadal ekstrapoluje z ostatniego syncu.
- Niepoprawny JSON / brakujące pole: `from_json` używa wartości domyślnych i `push_warning`;
  brak `x`/`y` (osada) lub `id`/`from`/`to` (flota) odrzuca rekord.
- Osada pod współrzędnymi, które `WorldGrid` uznaje za morze: `push_error`, rekord odrzucony
  (sygnał rozjazdu algorytmu klient–serwer, ADR 0001).
- Nieznany biom → `TEMPERATE`. Nieznany budynek lub budynek spoza biomu ignorowany.
- `set_active_settlement` na cudzą osadę: `push_error`, brak zmiany.
- Tap poza wyspą: bez akcji.

## 11. Testy i weryfikacja

- gdUnit4 w `addons/`, uruchamiane headless z CLI (komenda do potwierdzenia po instalacji,
  docelowo `Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/`).
- `test/core/`: `CoastlineGenerator` (determinizm, liczba punktów, zakres promieni,
  triangulacja), `WorldGrid` (determinizm, gęstość 10–25 % na próbce 100×100,
  odwracalność cell↔world, deposit zawiera tylko zasoby spoza biomu), `Biome`
  (każdy biom ma dokładnie 2 zasoby i 2 budynki wydobywcze), `Settlement` (`from_json`
  pełny/publiczny/braki, `current_resources` 0 h / 2 h / capacity / ujemny delta,
  odrzucenie budynku spoza biomu), `Fleet` (`progress` przed/w trakcie/po, `total_ships`),
  `Navigation` (zero, wiatr w plecy, pod wiatr, prostopadły, clamp, najwolniejszy statek),
  `TimeUtil` (ISO 8601 z `Z` i z offsetem, `format_amount`), `Coord` (`key` odwracalny).
- `test/api/`: `MockProvider` zwraca poprawne struktury; fixtures na lądzie wg `WorldGrid`;
  budynki fixtures zgodne z biomem.
- Smoke test: `Godot --headless --path . --quit` kończy się bez błędów skryptów.
- Ręcznie w edytorze: pan, pinch (emulacja z myszy), tap → detail w trzech trybach → powrót,
  HUD rośnie, nadchodząca flota na czerwono.
- Ryzyko: Godot 4.8 dev4 to build deweloperski. Jeśli gdUnit4 nie działa, wracamy do
  użytkownika z opcją własnych skryptów testowych.

## 12. Kolejność implementacji

1. `project.godot`, struktura katalogów, gdUnit4, smoke test.
2. `scripts/core/`: `TimeUtil`, `Coord`, `Resources`, `Buildings`, `Biome`, `World`,
   `Settlement`, `Fleet` z testami.
3. `CoastlineGenerator` + testy, `IslandGenerator` (podgląd w edytorze).
4. `WorldGrid` (z `Island` i deposit) + testy, `Navigation` + testy.
5. Warstwa API: `ApiProvider`, `MockProvider` + fixtures + testy, `HttpProvider` szkielet.
6. Autoloady: `GameState`, `ApiClient`, `SceneManager`; `Main.tscn`.
7. `WorldMap` + `MapCamera` + chunkowanie + tap + etykiety osad.
8. `IslandDetail` (trzy tryby) + `BuildingMenu`.
9. `HUD` z lazy resources.
10. `FleetRenderer`.
