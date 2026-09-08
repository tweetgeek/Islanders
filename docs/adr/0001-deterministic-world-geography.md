---
status: accepted
---
# Geografia świata liczona deterministycznie z seeda, wyspa identyfikowana przez współrzędne

Mapa świata w grze typu Tribal Wars jest stała, zmienia się tylko stan osad. Zamiast trzymać wyspy jako rekordy z własnym `id` i serwować geometrię przez API, istnienie, kształt, biom i znalezisko każdej wyspy wynikają deterministycznie z `worldSeed` i współrzędnych komórki `(x, y)` przez `FastNoiseLite` i hash. Klient rysuje całą mapę bez requestów, a tożsamością wyspy jest `(worldId, x, y)`; serwer przechowuje tylko osady (stan gracza) pod tym samym kluczem.

## Konsekwencje

- Algorytm placementu i promienia wyspy jest częścią kontraktu klient–serwer (patrz Załącznik); zmiana po otwarciu świata to migracja całego świata. Backend NestJS musi mieć identyczną implementację `WorldGrid` (ten sam szum, ten sam hash). Wygląd narysowanego wybrzeża (`CoastlineGenerator`) jest czysto renderingowy i NIE wchodzi w ten kontrakt — patrz Załącznik, sekcja „Poza zakresem kontraktu”.
- Mgła wojny na poziomie geografii jest niemożliwa, bo klient zna wszystkie wyspy; tajemnicą pozostaje wyłącznie stan osad.
- Nowy rodzaj celu floty na komórce morza wymagałby rozszerzenia siatki o trzeci stan komórki, czego celowo nie robimy.

## Odrzucone alternatywy

- Serwer jako jedyne źródło geometrii (`GET /world?chunk=`): mapa „skacze” przy przewijaniu, mock musi udawać cały świat, algorytm i tak trzeba by napisać po stronie serwera.
- Serwerowe `id` liczbowe obok współrzędnych: dwa klucze dla jednego bytu, rozjazdy między klientem znającym `(x, y)` a serwerem znającym `id`.

## Załącznik: co dokładnie musi odtworzyć backend

Ten spis powstał z czytania `scripts/core/WorldGrid.gd`, `scripts/core/Biome.gd`
i `scripts/core/ResourceTypes.gd` — nie jest streszczeniem z pamięci. Backend NestJS musi
odtworzyć każdy z poniższych punktów bit-w-bit; pominięcie jednego z pozoru nieistotnego
elementu (np. kolejności listy zasobów) daje świat, który *wygląda* poprawnie, ale osady lądują
gdzie indziej niż u klienta.

### 1. Hash komórki (`WorldGrid.hash_cell`)

31-bitowy hash, wynik zawsze w `[0, 0x7fffffff]`:

```
h = world_seed & 0x7fffffff
h = (h * 31 + cell.x + 1000003) & 0x7fffffff
h = (h * 31 + cell.y + 1000033) & 0x7fffffff
h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
```

Stałe `31`, `1000003`, `1000033`, `13`, `1274126177` i maska `0x7fffffff` są częścią kontraktu
— nie „magicznymi liczbami do wyczyszczenia”. `hash_cell` jest też używany rekurencyjnie do
generowania podhashy dla znaleziska (patrz punkt 4), z konkretnymi wektorami-solami
`(7, 11)`, `(3, 5)`, `(1, 1)`, `(i + 1, 0)` — to też trzeba przepisać dosłownie.

Wynik `h` jest też przypisywany wprost jako `Island.seed_val` (patrz `WorldGrid.island_at`) —
to ta sama liczba, której backend musi liczyć dla promienia i znaleziska (punkty 6 i 7), a nie
osobna, tylko-kliencka wartość. Klient zużywa `seed_val` powtórnie jako ziarno `CoastlineGenerator`
do narysowania wygiętego konturu wybrzeża — to jedyne miejsce, gdzie kontraktowa wartość `h`
zasila coś, co samo w sobie kontraktem nie jest (patrz punkt 2 i „Poza zakresem kontraktu” niżej).

**Krytyczne dla implementacji w JavaScript/TypeScript:** wynik pośredni
`(h ^ (h >> 13)) * 1274126177` sięga rzędu 2,7 × 10^18 — daleko poza bezpieczny zakres liczb
całkowitych JavaScriptu (`Number.MAX_SAFE_INTEGER` = 2^53 − 1 ≈ 9,007 × 10^15), a operatory
bitowe JavaScriptu (`&`, `^`, `>>`) i tak działają tylko na 32 bitach. GDScript nie ma tego
problemu — jego `int` jest 64-bitowy, więc `hash_cell` liczy się w nim dokładnie bez żadnych
dodatkowych zabiegów. Naiwne przepisanie wzoru na `number` z `| 0`/`>>> 0` na końcu da
**błędny** wynik: dla `world_seed = 1337`, `cell = (103, 100)` (ten sam przykład co pierwszy
złoty test w `test/core/world_grid_test.gd`) prawidłowy `hash_cell` (policzony w 64-bitowej
arytmetyce, tak jak liczy go Godot) to `252586155`, a ten sam wzór przepisany dosłownie na
`number` w TypeScripcie, z maskowaniem `& 0x7fffffff` na końcu, daje `252586152` — różnica
bierze się z utraty precyzji już przy samym mnożeniu przez `1274126177`, zanim dojdzie do
maskowania bitowego. Dla `world_seed = 1337` to jedna komórka; w praktyce zmieniłoby to promień
i znalezisko praktycznie każdej wyspy w świecie, bo błąd zależy od `(x, y)` w sposób, którego
nikt by ręcznie nie zauważył. Backend musi liczyć `hash_cell` (i podać wynik do `hash01`) w
arytmetyce 64-bitowej: w TypeScripcie oznacza to `BigInt` na każdym kroku tej funkcji (`h`,
mnożenie, XOR, przesunięcie, maskowanie) — nigdy `number` ani obcinanie przez `| 0`/`>>> 0`.

### 2. `WorldGrid.hash01(h)` — zamiana zhashowanej liczby na `[0, 1)`

```
hash01(h) = float(h % 10007) / 10007.0
```

Uwaga terminologiczna: w kliencie istnieje też `CoastlineGenerator._mix_seed01`, który hashuje
*surowy, jeszcze niezhashowany* seed (miesza bity przez XOR-shift-multiply, dopiero potem robi
`% 10007`). To inna funkcja o innym kontrakcie, używana tylko do rysowania kształtu wybrzeża —
nie jest częścią kontraktu geografii i backend nie musi jej odtwarzać. Kontraktem jest wyłącznie
`WorldGrid.hash01`. (Zobacz „Konsekwencje” wyżej i „Poza zakresem kontraktu” niżej: kontrakt
obejmuje ISTNIENIE i PROMIEŃ wyspy, nie rendering jej wybrzeża — mimo że oba korzystają z tego
samego `seed_val`, patrz punkt 1.)

### 3. Konfiguracja szumu (`FastNoiseLite`) — w całości, łącznie z domyślnymi polami

Dwa niezależne szumy na `worldSeed`:

| pole | szum lądu | szum biomu |
|---|---|---|
| `seed` | `world_seed` | `world_seed + 1` |
| `noise_type` | `TYPE_SIMPLEX_SMOOTH` | `TYPE_SIMPLEX_SMOOTH` |
| `fractal_octaves` | `2` | `1` |
| `frequency` | `LAND_FREQUENCY = 0.12` | `BIOME_FREQUENCY = 0.03` |

Pola, których kod nie ustawia, i tak wpływają na wynik, bo `FastNoiseLite` ma je niezerowe
domyślnie (zmierzone na instancji `FastNoiseLite.new()` w Godot 4.8.dev4):
`fractal_type = FRACTAL_FBM`, `fractal_lacunarity = 2.0`, `fractal_gain = 0.5`,
`fractal_weighted_strength = 0.0`, `fractal_ping_pong_strength = 2.0`, `offset = (0, 0, 0)`,
`domain_warp_enabled = false`. Backend musi je jawnie ustawić na te same wartości — nie może
polegać na „domyślnych ustawieniach” swojej biblioteki szumu, bo inna biblioteka ma inne domyślne.
Próbkowanie jest wołane jako `get_noise_2d(cell.x, cell.y)` — na surowych całkowitych
współrzędnych komórki, bez skalowania przez `CELL_SIZE`.

Jeśli backend nie implementuje identycznego algorytmu OpenSimplex2S (to kryje się pod
`SIMPLEX_SMOOTH` w Godocie) z tą samą kolejnością oktaw, wyniki się rozjadą mimo identycznych
parametrów wejściowych — sama zgodność parametrów nie wystarczy, trzeba zgodności implementacji.

### 4. Próg lądu (`LAND_THRESHOLD`)

```
komórka jest morzem, gdy szum_lądu.get_noise_2d(x, y) <= LAND_THRESHOLD (0.30)
w przeciwnym razie jest lądem (wyspą)
```

### 5. Pasmowanie biomu (`BIOME_BAND`)

Dla `b = szum_biomu.get_noise_2d(x, y)`:

```
b < -BIOME_BAND (-0.15)  -> TROPICAL
b >  BIOME_BAND ( 0.15)  -> VOLCANIC
w przeciwnym razie       -> TEMPERATE
```

### 6. Promień wyspy

```
h = hash_cell(world_seed, cell)
radius = RADIUS_MIN + (RADIUS_MAX - RADIUS_MIN) * hash01(h)
```

`RADIUS_MIN = 60.0`, `RADIUS_MAX = 110.0`.

### 7. Reguły znaleziska (`_deposit_for`, ADR 0002: tylko zasoby SPOZA biomu wyspy)

```
h2 = hash_cell(h, Vector2i(7, 11))
jeśli hash01(h2) >= DEPOSIT_CHANCE (0.3) -> brak znaleziska (pusty słownik)

foreign = [r dla r w ResourceTypes.ALL, jeśli r nie należy do Biome.resources(biome)]

h3 = hash_cell(h2, Vector2i(3, 5))
count = 1 + int(hash01(h3) * 2.0)                       # 1 albo 2 zasoby
start = int(hash01(hash_cell(h3, Vector2i(1, 1))) * foreign.size())

dla i w range(count):
    r  = foreign[(start + i) % foreign.size()]
    h4 = hash_cell(h3, Vector2i(i + 1, 0))
    ilość[r] = float(200 + int(hash01(h4) * 800.0))     # liczba całkowita w [200, 999]
```

**Kolejność iteracji, która po cichu ma znaczenie:** `foreign` budowany jest przez iterację
`ResourceTypes.ALL` w jej zadeklarowanej kolejności
(`["wood", "stone", "food", "iron", "sulfur"]`). Indeksy `start` i `(start + i) % foreign.size()`
wybierają konkretne pozycje z tej listy, więc **zmiana kolejności `ResourceTypes.ALL` zmienia
znalezisko każdej wyspy w każdym świecie** — bez zmiany jednej linijki logiki. To samo dotyczy
`Biome.resources(biome)` użytego tylko do testu przynależności (`.has()`), więc jej kolejność
akurat nie ma znaczenia — ale `ResourceTypes.ALL` ma i backend musi trzymać identyczną kolejność
tej listy.

### Poza zakresem kontraktu (geografii)

`CELL_SIZE`, `CHUNK_SIZE`, `world_to_cell`/`cell_to_world`, sposób grupowania w chunki,
`Biome.colors` oraz sam układ slotów budynków w `Biome.slots` (rozmieszczenie na okręgu,
kolejność wizualna) i kształt narysowanego wybrzeża (`CoastlineGenerator`, patrz punkty 1 i 2)
to sprawy renderowania i UI klienta, nie geografii — backend nie musi ich znać, żeby wysyłać
zgodne z klientem `(worldId, x, y)`.

**To nie znaczy, że mapowanie biom → dozwolone budynki wydobywcze (`Biome.extraction_buildings`,
ADR 0002) jest wyłącznie sprawą UI.** Backend musi znać to samo mapowanie, żeby odrzucać próby
budowy budynku wydobywczego zasobu spoza biomu osady — to osobny, współdzielony kontrakt (reguła
gry z ADR 0002), niezależny od kontraktu geografii opisanego w tym załączniku. Innymi słowy:
backend nie musi wiedzieć, GDZIE narysować ikonę slotu na okręgu (to UI), ale musi wiedzieć,
KTÓRE budynki wolno postawić na wyspie danego biomu (to reguła gry, egzekwowana też po stronie
serwera).
