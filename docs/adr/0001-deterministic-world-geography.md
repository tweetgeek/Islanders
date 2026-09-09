---
status: accepted
---
# Geografia świata liczona deterministycznie z seeda, wyspa identyfikowana przez współrzędne

Mapa świata w grze typu Tribal Wars jest stała, zmienia się tylko stan osad. Zamiast trzymać wyspy jako rekordy z własnym `id` i serwować geometrię przez API, istnienie, kształt, biom i znalezisko każdej wyspy wynikają deterministycznie z `worldSeed` i współrzędnych komórki `(x, y)` przez `FastNoiseLite` i hash. Klient rysuje całą mapę bez requestów, a tożsamością wyspy jest `(worldId, x, y)`; serwer przechowuje tylko osady (stan gracza) pod tym samym kluczem.

**Zmiana implementacji szumu.** Powyższy akapit opisuje decyzję w chwili jej podjęcia; od tego czasu `FastNoiseLite` został usunięty z algorytmu geografii i zastąpiony szumem wartościowym zbudowanym na `hash_cell`, który klient już miał jako część kontraktu (patrz Załącznik, sekcje 2 i 3). Nie dlatego, że `FastNoiseLite` działał źle — działał poprawnie i wyglądał dobrze. Dlatego, że kontrakt, który potrafi pewnie zaimplementować tylko jedna strona, nie jest kontraktem: odtworzenie OpenSimplex2S (kryjącego się pod `TYPE_SIMPLEX_SMOOTH`) w TypeScripcie to setki linii cudzej matematyki, w której każda różnica w kolejności działań daje inny świat, wyglądający całkowicie poprawnie. Szum wartościowy to około trzydziestu linii dodawania, mnożenia i interpolacji na `float`, bez funkcji przestępnych — obie strony liczą je identycznie, bo obie używają IEEE 754 binary64. `CoastlineGenerator` dalej używa `FastNoiseLite` do rysowania wybrzeża — to zostaje bez zmian, bo kształt wybrzeża jest czysto renderingowy i nigdy nie wchodził w ten kontrakt (patrz „Poza zakresem kontraktu” niżej). Zgodność implementacji między klientem a backendem pilnuje teraz `contract/world-parity.json` (patrz `contract/README.md`): zrzut geografii dla kilku ziaren świata, który backend sprawdza komórka po komórce — to on ma wyłapać rozjazd, zanim wyłapie go gracz widzący własną osadę na morzu.

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

`hash01` ma dziś drugiego konsumenta oprócz promienia i znaleziska (punkty 6 i 7): jest cegiełką
szumu wartościowego z punktu 3 niżej (`_lattice`). To ta sama funkcja, wołana z tymi samymi
regułami — backend nie implementuje osobnego `hash01` na potrzeby szumu.

### 3. Szum wartościowy oparty na haszu (zastępuje `FastNoiseLite`)

Dwie niezależne funkcje `fbm` na `worldSeed`, obie zbudowane wyłącznie na `hash_cell`/`hash01`
z punktów 1 i 2 — żadnych funkcji przestępnych, żadnej biblioteki szumu:

```
lattice(seed, ix, iy) = hash01(hash_cell(seed, ix, iy)) * 2.0 - 1.0     # w [-1, 1)

smooth(t) = t * t * (3.0 - 2.0 * t)

value_noise(seed, x, y):
    ix = floor(x);  iy = floor(y)
    fx = x - ix;    fy = y - iy
    u = smooth(fx); v = smooth(fy)
    n00 = lattice(seed, ix,     iy)
    n10 = lattice(seed, ix + 1, iy)
    n01 = lattice(seed, ix,     iy + 1)
    n11 = lattice(seed, ix + 1, iy + 1)
    a = n00 + (n10 - n00) * u
    b = n01 + (n11 - n01) * u
    return a + (b - a) * v

fbm(seed, x, y, octaves):
    sum = 0.0;  norm = 0.0;  amp = 1.0;  freq = 1.0
    for i in 0 .. octaves - 1:
        sum  = sum + amp * value_noise(seed + i * 1013, x * freq, y * freq)
        norm = norm + amp
        amp  = amp * 0.5
        freq = freq * 2.0
    return sum / norm

land  = fbm(world_seed,     x * LAND_FREQUENCY,  y * LAND_FREQUENCY,  2)
biome = fbm(world_seed + 1, x * BIOME_FREQUENCY, y * BIOME_FREQUENCY, 1)
```

Wołane na surowych całkowitych współrzędnych komórki `(x, y)`, bez skalowania przez `CELL_SIZE` —
tak jak dawniej `get_noise_2d`. `LAND_FREQUENCY = 0.12` i `BIOME_FREQUENCY = 0.03` przeniesione
bez zmian.

Wiążące dla obu implementacji:

- `floor` musi być matematyczną podłogą, także dla ujemnych współrzędnych. W TypeScripcie
  `Math.floor`, nigdy `Math.trunc`, `| 0` ani `parseInt` — te obcinają w stronę zera, co dla
  ujemnych wejść daje inny wynik niż podłoga.
- Kolejność działań w `fbm` jest częścią kontraktu: sumowanie w innej kolejności zmienia wynik na
  ostatnich bitach, a próg lądu (punkt 4) potrafi to wzmocnić do różnicy „ląd albo morze”.
- Sól oktawy `1013` oraz mnożniki `0.5` (amplituda) i `2.0` (częstotliwość) są kontraktem.
- Wynik mieści się w przybliżeniu w `[-1, 1]`, ale nie dokładnie — nie polegaj na krańcach zakresu.
- Wszystkie działania to dodawanie, odejmowanie, mnożenie i dzielenie na `float` (IEEE 754
  binary64), które GDScript i TypeScript liczą identycznie — bez tego zastrzeżenia dotyczącego
  `hash_cell` z punktu 1 (BigInt), bo tu nigdzie nie ma arytmetyki całkowitoliczbowej poza samym
  `hash_cell`.

Algorytm zweryfikowano na prototypie w GDScript i w JavaScripcie z `BigInt`: obie implementacje
dają identyczne wartości `land` i `biome` do siedemnastu cyfr znaczących, także dla ujemnych
współrzędnych. `contract/world-parity.json` (patrz `contract/README.md`) jest bieżącym,
uruchamialnym dowodem tej zgodności — backend ma test, który czyta ten plik i sprawdza swoją
implementację komórka po komórce, dla siatki co najmniej 200 × 200 i kilku ziaren.

### 4. Próg lądu (`LAND_THRESHOLD`)

```
komórka jest morzem, gdy land <= LAND_THRESHOLD (0.30)
w przeciwnym razie jest lądem (wyspą)
```

`land` liczone jak w punkcie 3. Nowy szum ma inny rozkład niż `FastNoiseLite`, więc próg wymagał
ponownego sprawdzenia: na próbce 100 × 100 dla trzech ziaren (1, 1337, 99999) `LAND_THRESHOLD =
0.30` daje gęstość lądu 18,1%, w docelowym przedziale 15–20%, więc wartość progu zostaje bez
zmian.

### 5. Pasmowanie biomu (`BIOME_BAND`)

Dla `b = biome` liczonego jak w punkcie 3:

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
