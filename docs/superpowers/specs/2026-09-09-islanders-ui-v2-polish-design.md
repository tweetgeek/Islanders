# Islanders – UI v2, korekty po przeglądzie na urządzeniu

Data: 2026-09-09
Status: zatwierdzony w brainstormingu, uzupełniony po sesji grillowania 2026-09-10 i przy planowaniu;
plan: `docs/superpowers/plans/2026-09-10-islanders-ui-v2-polish.md`
Poprzedni spec: `2026-09-08-islanders-ui-v2-design.md`. Ten dokument go nie zastępuje; nadpisuje
sekcje 3.4, 3.5, 4.2, 4.3, 5, 6.4 i 7 oraz decyzje o placeholderze złota, o przyciemnianiu kart
i o zasadzie „zero zewnętrznych grafik”.
Decyzje architektoniczne: ADR 0003 (położenie wyspy wyznacza odległość podróży) i nowy punkt 8
załącznika kontraktu w ADR 0001.

Terminologia zgodna z `CONTEXT.md`. Glosariusz ma pierwszeństwo.

## 1. Cel i pochodzenie

Po scaleniu UI v2 właściciel projektu uruchomił grę i zgłosił cztery zarzuty: górny pasek jest za
wysoki, elementy mają za dużo odstępów, elementy nie są ostre, wyspy są zbyt blisko siebie.

Diagnoza pomiarowa w działającej grze, przy oknie równym viewportowi (1080 × 1920):

| Zarzut | Ustalenie |
|---|---|
| Za wysoki pasek | 469 px, czyli 24,4 % wysokości ekranu. Wierne odwzorowanie makiety, która miała ~150 z 844 px. Nie usterka, lecz zmiana decyzji projektowej. |
| Za duże odstępy | Każdy margines z makiety przechodzi przez `SCALE = 2.77`, a nakładają się trzy poziomy zagnieżdżenia: pasek 12, karta 6 i 8, chip 8 i 5. Proporcjonalnie zgodne, kumulatywnie ciężkie. |
| Brak ostrości | Renderowanie jest ostre. Zrzuty zgłaszającego miały 571 px szerokości przy canvasie 1080, czyli zostały zmniejszone o połowę. Realne są dwie inne rzeczy: przyciemnione karty i ikona kamienia. |
| Wyspy zbyt blisko | Komórka 256 px, promień do 110 px, woda przybrzeżna w skali 1,18. Średni prześwit między obwódkami ~55 px, dla pary największych wysp ujemny. |

Diagnoza wykazała dodatkowo usterkę, której nie widział żaden z jedenastu przeglądów: etykieta
nazwy osady miała poprawny `text` i szerokość jednego piksela, więc nazwa była niewidoczna.
Naprawiona osobno, przed tą falą, commitem `e38b24f` na gałęzi `fix/hud-settlement-name`, wraz
z dwoma testami mierzącymi wyrenderowaną szerokość zamiast właściwości tekstu.

Ten spec obejmuje falę drugą: strukturę paska, gęstość odstępów, geometrię mapy i czytelność.

Sesja grillowania 2026-09-10 zmieniła cztery rzeczy względem pierwszej wersji tego dokumentu:
przesunięcie wyspy przestało być renderingiem i weszło do kontraktu, wyznaczając odległość
podróży (5.2, ADR 0003); tapnięcie wyspy na mapie zawsze ją ogląda, nigdy nie aktywuje (5.5);
właściciel osady i floty jest pokazywany pseudonimem (7); zasada „zero zewnętrznych grafik”
została zniesiona (2).

Poza zakresem: zmiana promieni zaokrągleń i wyłączanie wygładzania krawędzi (renderowanie jest
obiektywnie ostre), zmiana promieni wysp (należą do kontraktu parytetu), nowa waluta w miejsce
usuwanego placeholdera złota, przejście ikon z glifów na grafiki (osobna decyzja o stylu),
implementacja czasu podróży po stronie backendu (strona API, patrz ADR 0003).

## 2. Decyzje

| Decyzja | Wybór | Uzasadnienie |
|---|---|---|
| Wysokość paska | Dwa wiersze, cel ~14 %, próg testowy 16 % | Wybór właściciela z trzech wariantów; tempo produkcji zostaje, populacja się przenosi |
| Populacja | Przenosi się do widoku osady | Dotyczy osady aktywnej; rekrutacja i wysyłanie flot startują z osady |
| Placeholder złota | Usuwany | Pokazuje zero i nie jest z niczym połączony; zajmuje szerokość potrzebną wierszowi tożsamości |
| Awatar kotwicy | Usuwany | Statyczny glif bez informacji, 111 px szerokości |
| Gęstość odstępów | Jedno pokrętło `DENSITY` niezależne od `SCALE` | Zagęszcza cały interfejs bez zmniejszania tekstu i ikon; jedna liczba do korekty po ocenie na urządzeniu |
| Rozsunięcie wysp | `CELL_SIZE` 256 → 448 | Nie należy do kontraktu parytetu, więc backend nietknięty |
| Rozbicie siatki | Deterministyczne przesunięcie środka w obrębie komórki, ±0,13 komórki, część kontraktu | Wyspy przestają czytać się jako rzędy; zakres sprawdzony pomiarem konturów wody (5.2) |
| Odległość podróży | Między położeniami wysp, nie między komórkami (ADR 0003) | Mapa organiczna i wierna jednocześnie: to, co widać, to, co płynie flota |
| Tapnięcie wyspy | Zawsze ogląda, także własną i aktywną osadę; nigdy nie aktywuje | Osada aktywna jest źródłem floty; wskazanie własnej osady jako celu transportu musi być możliwe |
| Arkusz własnej osady | Dane publiczne, oznaczenie „twoja”, przycisk „Przejdź do osady” / „Wróć do osady” | Pełne dane prywatne są o jedno tapnięcie dalej, w widoku osady |
| Właściciel | Pseudonim z `ownerName` wszędzie, własna osada „Ty” | Glosariusz: pseudonim to jedyna informacja o koncie widoczna dla innych; backend już go wysyła |
| Podpis w pasku | Numer świata i współrzędne | Współrzędne to tożsamość wyspy; numer świata rozróżnia profile na wielu światach |
| Gęstość i przybliżenie | Start `DENSITY` 0,7 i `ZOOM_MIN` 0,15, strojenie po przeglądzie wizualnym | Wartości wybrane z wyczucia; rozstrzyga obraz, nie argument |
| Zewnętrzne grafiki | Zasada zniesiona, także w interfejsie gry | Decyzja właściciela po dodaniu logo aplikacji |
| Ikony w tej fali | Zostają glifami rysowanymi kodem | Zniesienie zasady nie wybiera stylu; przejście na grafiki to osobny projekt |
| Ostrość krawędzi | Bez zmian | Renderowanie jest ostre; miękkość w zgłoszeniu była artefaktem zrzutu |
| Stan „nie produkuję” | Paleta i treść, nie przezroczystość | `modulate` mnoży alfę dzieci, co odbierało czytelność liczbie |

## 3. Górny pasek

### 3.1 Struktura

```
TopBar (PanelContainer, wariacja BarPanel, offset_top = SafeArea.top_inset)
└── Pad (MarginContainer, gap(12))
    └── BarRows (VBoxContainer, gap(9))
        ├── IdentityRow (HBoxContainer, gap(10))
        │   ├── SettlementName (Label, Title, clip_text, SIZE_EXPAND_FILL)
        │   ├── BiomeBadge (Label, Badge)
        │   └── Subtitle (Label, Caption)
        └── ResourceGrid (HBoxContainer, gap(6)) → ResCard × 5
```

Usuwane węzły: `Avatar`, `GoldPanel` z dziećmi, `PopulationRow` z dziećmi, oraz kontenery
`Identity` i `NameRow`, które przy jednej linii tożsamości nie mają już racji bytu.

### 3.2 Budżet wysokości

| Składnik | Wartość |
|---|---|
| Marginesy `Pad`, góra i dół | 2 × 23 = 46 |
| Separacja między wierszami, `gap(9)` | 17 |
| `IdentityRow` | 64 |
| `ResourceGrid` | ~140 |
| Razem | ~267 px, czyli 13,9 % z 1920 |

Próg testowy 16 % to 307 px, czyli 40 px zapasu na wahania metryk fontu.

Liczby zakładają `DENSITY = 0.7` z sekcji 4.

Wiersz tożsamości mieści się: nazwa potrzebuje 255 px, odznaka 168, podpis 256, razem
z odstępami ~711 przy dostępnych 1034. Nazwa ma `clip_text` i `SIZE_EXPAND_FILL`, więc pochłania
luz i przy długiej nazwie obcina się, nigdy nie wypychając odznaki.

### 3.3 Populacja w widoku osady

`IslandDetail` dostaje plakietkę w lewym dolnym rogu, nad dokiem, obok istniejącej podpowiedzi:
`Icon "people"`, `ProgressBar` i `Label` z „42 / 120”. Ostrzeżenie kolorem `BLOOD` przy
zapełnieniu od 95 % zachowuje się jak dotąd, tylko w nowym miejscu. Na mapie populacji nie widać.

### 3.4 Orientacja pozioma

Mechanizm przenoszenia `ResourceGrid` między kontenerami zostaje; celem staje się `IdentityRow`
zamiast usuniętego `ProfileRow`. W poziomie pasek schodzi do jednego wiersza.

## 4. Pokrętło gęstości

`MedievalTheme` dostaje `DENSITY := 0.7` i drugą funkcję obok `px()`:

```gdscript
## Odstęp: przestrzeń między elementami i wokół nich. Skalowana dodatkowo gęstością,
## żeby dało się zagęścić interfejs bez zmniejszania tekstu i ikon.
static func gap(v: float) -> int:
	return int(roundf(v * SCALE * DENSITY))
```

Zasada podziału jest rozstrzygalna jednym pytaniem: czy liczba jest przestrzenią **między**
rzeczami, czy rozmiarem **samej** rzeczy.

| Przez `gap()` | Przy `px()` |
|---|---|
| marginesy wewnętrzne kart, chipów i arkuszy | rozmiary fontów |
| separacje kontenerów | boki ikon |
| margines paska i warstwy UI mapy | wysokości przycisków |
| odstępy w doku i w kolumnie przybliżania | promienie zaokrągleń, grubości obramowań |
| separacja siatki kosztów i listy flot | cień plakietki, separacja `HSeparator` |
| | geometria świata (`SlotPlaque`, etykiety mapy) |

Jeden przypadek wymaga uwagi: wciśnięty przycisk `Primary` udaje zapadnięcie o 3 px, przesuwając
marginesy góra i dół w przeciwne strony. Bazowy margines idzie teraz przez `gap()`, więc wariant
wciśnięty musi być `gap(14)` plus i minus `px(3)`, inaczej zagęszczenie zmniejszyłoby też skok
i przycisk przestałby się wciskać widocznie.

## 5. Geometria mapy

### 5.1 Rozsunięcie

`WorldGrid.CELL_SIZE` z 256 na 448. Rozmiaru komórki w pikselach nie ma w kontrakcie parytetu
i nie będzie, bo backend pracuje w komórkach. Sam artefakt `contract/world-parity.json` wymaga
jednak przegenerowania z powodu przesunięcia wysp (5.2).

Konsekwencje:
- Świat rośnie z 51 200 na 89 600 px na bok. Granice kamery liczą się z rozmiaru świata razy
  rozmiar komórki, więc dopasowują się same.
- Przy najszerszym przybliżeniu widać 9,6 komórki zamiast 16,9. `MapCamera.ZOOM_MIN` schodzi
  z 0,25 na 0,15, żeby przegląd mapy pozostał podobny (16 komórek).
- Siatka wody rzednie, co jest poprawą wobec gęstej siatki na zgłoszonym zrzucie.
- `FleetRenderer.DASH` i `TRIANGLE` rosną proporcjonalnie (448 / 256 = 1,75): 24 → 42 i 14 → 24,
  żeby trasa i znacznik nie wyglądały na mniejsze wobec większych odległości.

### 5.2 Rozbicie siatki

```gdscript
## Przesunięcie położenia wyspy w obrębie komórki, w ułamkach komórki. Część kontraktu
## geografii (ADR 0001, Załącznik, punkt 8): wyznacza odległość podróży floty (ADR 0003).
const OFFSET_RANGE := 0.13
static func island_offset(world_seed: int, cell: Vector2i) -> Vector2      ## ułamki komórki
static func island_position(world_seed: int, cell: Vector2i) -> Vector2    ## jednostki komórek
static func island_center(world_seed: int, cell: Vector2i) -> Vector2      ## piksele, rendering
```

Wzór przesunięcia, z solami `(13, 17)` i `(19, 23)`, jest spisany w załączniku ADR 0001, punkt 8,
bo tam backend szuka formuł. `island_position` to `cell + offset` w jednostkach komórek i jest
kontraktem; `island_center` przelicza to na piksele przez `CELL_SIZE` i jest renderowaniem.

`Vector2` w standardowym buildzie Godota trzyma float32, więc zgubiłby ostatnie bity, które
backend porównuje dokładnie. Stąd czwarta funkcja, `island_offset_xy(world_seed, cell) ->
PackedFloat64Array`, liczy przesunięcie w pełnej precyzji double i to z niej pisze się artefakt
kontraktu; trzy funkcje wyżej są jej wygodnym, float32 widokiem dla renderowania i nawigacji.

Przesunięcie przestało być kosmetyką: jest zamrożoną stałą rozgrywki, jak próg lądu. Odległość
między bezpośrednimi sąsiadami w poziomie waha się od 0,74 do 1,26 komórki, co jest celową cechą
mapy — położenie wyspy ma znaczenie.

Zakres sprawdzony pomiarem na rzeczywistych konturach, nie wzorem. Pierwsza wersja tego
dokumentu liczyła wodę przybrzeżną jako koło o promieniu `radius × 1,18` i wychodziła jej
najgorszym prześwitem 72 px. Przy planowaniu okazało się, że to zły model: `CoastlineGenerator`
zaburza promień szumem do ±35 % i spłaszcza kontur elipsą 0,8–1,2, więc obwódka wody sięga
w medianie 1,42 promienia, a najdalej 1,77. Pomiar wielokątów `Shallow` dla wszystkich par
bezpośrednich sąsiadów (także po przekątnej) na obszarze 120 × 120 komórek:

| Konfiguracja | Pary | Nałożenia | Najmniejszy prześwit | 1. percentyl | Mediana |
|---|---|---|---|---|---|
| 256 px, bez przesunięcia (dziś), ziarno 1337 | 7518 | 174 | — | — | 78 px |
| 448 px, bez przesunięcia, ziarno 1337 | 7518 | 0 | 141 px | 178 px | 271 px |
| 448 px, ±0,13, ziarno 1337 | 7518 | 0 | 54 px | 124 px | 311 px |
| 448 px, ±0,13, ziarno 99999 | 6556 | 0 | 52 px | 124 px | 315 px |

Pierwsze zetknięcie obwódek pojawia się przy przesunięciu ~0,21 (ziarno 1337, prześwit 0,1 px);
przy 0,15 najmniejszy prześwit to 41 px, przy 0,17 — 28 px. Przyjęte `OFFSET_RANGE = 0.13`
zostawia więc zapas i żadnych nałożeń w próbie. Test klienta (sekcja 9) sprawdza ten warunek na
tych samych wielokątach, które rysuje `IslandGenerator`, a nie na przybliżeniu kołem.

### 5.3 Trafianie w wyspę i pozycje

Tapnięcie mierzy odległość od przesuniętego środka wyspy tapniętej komórki, zamiast od środka
komórki. Sąsiednich komórek sprawdzać nie trzeba: dysk trafienia sięga od środka komórki najdalej
na przesunięcie wzdłuż osi (58 px) plus promień trafienia (1,1 × 110 = 121 px), razem 179 px przy
połowie komórki 224 px, więc nigdy nie wychodzi poza własną komórkę. Test przypina ten warunek
analitycznie, żeby późniejsza zmiana stałych nie złamała go po cichu.

Tej samej przesuniętej pozycji używają: rozmieszczanie generatorów wysp w chunkach, pierścienie
osad, etykiety osad oraz trasy flot.

`Fleet.position_at(now)` dostaje drugi parametr `world_seed: int`, bo flota zna identyfikator
świata, ale nie jego ziarno. Bez tego linia trasy kończyłaby się obok wyspy, a nie na niej.
Konsumenci do poprawki: `FleetRenderer` i skok kamery po tapnięciu karty floty w `Sheets`.

`SeaNavigation.distance` i `travel_time` przyjmują położenia (`Vector2` w jednostkach komórek)
zamiast komórek i pozostają czystą geometrią; nowa `travel_time_between(world_seed, from_cell,
to_cell, speed, wind)` składa je z `WorldGrid.island_position`. Kierunek wiatru to wektor między
tymi samymi położeniami. Dziś nic w kliencie tego nie woła, bo czas przybycia przychodzi z serwera,
ale będzie to podstawą podglądu czasu podróży przy wysyłaniu flot i musi zgadzać się z backendem.

### 5.4 Dwie usterki ze zgłoszonego zrzutu

**Nachodzące etykiety osad** rozwiązują się skutkiem 5.1: etykieta ma 240 px szerokości, a
najmniejsza możliwa odległość środków to 332 px, więc nałożenie jest niemożliwe. Test przypina
ten stan, żeby nie wrócił.

**Plakietka „OSADA” zasłaniająca wyspę** schodzi do samej ikony w kwadracie `px(46)`, spójnie
z przyciskami doku i przybliżania. Napis jest zbędny przy strzałce powrotu, a plakietka przestaje
zajmować `px(110)` szerokości mapy.

### 5.5 Tapnięcie wyspy i arkusz własnej osady

Tapnięcie dowolnej wyspy na mapie czyni ją oglądaną i otwiera arkusz oglądanej wyspy. Dotyczy to
także własnej osady, w tym aktywnej. Tapnięcie nigdy nie zmienia osady aktywnej; zmienia ją
wyłącznie świadome przełączenie (glosariusz, **Active Settlement**).

Powód: osada aktywna jest źródłem floty. Przy dzisiejszym zachowaniu, w którym tapnięcie własnej
osady od razu ją aktywuje, nie da się wskazać własnej osady jako celu floty z misją `TRANSPORT`,
bo tapnięcie celu zamienia go w źródło.

`InspectSheet` dostaje trzeci tryb, obok cudzej osady i wyspy niczyjej:

| Element | Własna osada nieaktywna | Własna osada aktywna |
|---|---|---|
| Nagłówek | nazwa, biom | nazwa, biom |
| Podpis | współrzędne · „twoja osada” | współrzędne · „twoja osada” |
| Akcja | `Primary` „Przejdź do osady”: aktywuje i przełącza do widoku osady | `Primary` „Wróć do osady”: tylko przełącza widok |

Dane prywatne nie są powielane w arkuszu; są o jedno tapnięcie dalej, w widoku osady.

## 6. Czytelność kart i ikony

### 6.1 Stan „nie produkuję tego zasobu”

Dziś cała karta dostaje `modulate.a = 0.45`, co mnoży alfę karty razem z jej dziećmi: pergamin
staje się półprzezroczysty na brązowym tle i wychodzi błoto, a liczba blaknie razem z nim.
Zamiast tego stan komunikują paleta i treść, przy pełnej nieprzezroczystości:

| Element | Zasób produkowany | Zasób nieprodukowany |
|---|---|---|
| Tło karty | `PARCHMENT` | `VELLUM` |
| Liczba | `INK` | `INK_SOFT` |
| Ikona | kolor zasobu (`ResourceTypes.COLORS`) | `INK_SOFT` |
| Tempo | zielone `+120/h` | puste |

`VELLUM` jest już w palecie jako kolor wgłębień, więc nie wprowadzamy nowego koloru. Stała
`DIMMED` znika. Efekt uboczny: testy porównują kolory zamiast alfy, co usuwa problem
32-bitowej składowej przezroczystości, który wcześniej wymusił osobne rozstrzygnięcie
o tolerancji w asercji.

### 6.2 Ikona kamienia

Płaski sześciokąt w szarości czyta się w tej skali jak plama. Zmienia się w bryłę z jedną
wewnętrzną krawędzią dzielącą ją na dwie płaszczyzny, rysowaną kolorem wycięcia. Zostaje na
siatce 24 jednostek i przy jednym kolorze plus wycięcie.

### 6.3 Kolor wycięcia w `Icon`

Kolor wycięcia jest dziś wpisany na sztywno jako `PARCHMENT` w kilku glifach (`town_hall`,
`warehouse`, `map`, `sulfur`, `gold`, `trade`), co zakłada pergaminowe tło. Ikona kamienia
pojawia się na pergaminie w pasku, na wellum w karcie nieprodukowanej i w chipach na ciemnym
dębie, więc wycięcie w kolorze pergaminu byłoby tam błędem.

`Icon` dostaje `@export var knockout: Color = MedievalTheme.PARCHMENT`, ustawiany tam, gdzie tło
jest inne: nagłówki arkuszy i przyciski doku na `OAK`, chipy zasobów na `OAK_DEEP`. Domyślna
wartość zachowuje dzisiejszy wygląd wszędzie, gdzie nikt jej nie ustawi. Końcowy przegląd całej
gałęzi wskazał tę zmianę jako pracę na później; ikona kamienia czyni ją warunkiem.

## 7. Pseudonim właściciela

Glosariusz definiuje pseudonim jako jedyną informację o koncie widoczną dla innych graczy.
Interfejs pokazywał zamiast niego numeryczny identyfikator konta w trzech miejscach: etykieta
osady na mapie, podpis arkusza oglądanej wyspy i skład obcej floty w karcie.

Backend wysyła już `ownerName` w publicznym widoku osady i w widoku floty. `Settlement.from_json`
i `Fleet.from_json` czytają to pole, a wszystkie trzy miejsca pokazują pseudonim. Własna osada
nadal pokazuje „Ty”. Atrapa danych (`fixtures/settlements.json`, `fixtures/fleets.json`) dostaje
to pole, a specyfikacja szkieletu klienta, sekcja 4.2, dostaje korektę opisu danych publicznych.

Do przekazania stronie API: publiczny widok osady nadal wysyła `ownerId`, co w świetle tej samej
reguły glosariusza jest wyciekiem identyfikatora konta.

## 8. Zmiany interfejsu i konsumenci

| Znika | Pojawia się | Konsumenci do poprawki |
|---|---|---|
| `HUD.gold_label` | — | `test/scenes/hud_test.gd` |
| `HUD.pop_bar`, `HUD.pop_label` | `IslandDetail.pop_bar`, `IslandDetail.pop_label` | `hud_test`, `island_detail_test`, `tools/smoke_probe.gd` |
| `HUD.DIMMED` | — | `hud_test` |
| `WorldMap.BACK_WIDTH` | — | `world_map_test` |
| — | `MedievalTheme.DENSITY`, `gap()` | `medieval_theme_test` |
| — | `WorldGrid.island_offset`, `island_center`, `OFFSET_RANGE` | `world_grid_test`, `world_map_test` |
| `Fleet.position_at(now)` | `Fleet.position_at(now, world_seed)` | `fleet_test`, `FleetRenderer`, `Sheets` |
| — | `Icon.knockout` | `icon_test` |
| — | `WorldGrid.island_position` | `world_grid_test`, `tools/world_parity_dump.gd` |
| — | `WorldGrid.island_offset_xy` (double, dla artefaktu kontraktu) | `world_grid_test`, `tools/world_parity_dump.gd` |
| — | `GameState.world_seed()`, `IslandGenerator.shallow_outline()` | `WorldMap`, `FleetRenderer`, `Sheets`, `world_map_test` |
| `SeaNavigation.distance(Vector2i, Vector2i)`, `travel_time(Vector2i, …)` | wersje na położeniach `Vector2` plus `travel_time_between(world_seed, …)` | `sea_navigation_test` |
| — | `Settlement.owner_name`, `Fleet.owner_name` | `settlement_test`, `fleet_test`, fixtures |
| tapnięcie własnej osady aktywuje | tapnięcie zawsze ogląda | `world_map_test`, `tools/smoke_probe.gd` |
| — | tryb własnej osady w `InspectSheet` | `inspect_sheet_test` |

## 9. Testy

- **Pasek**: wysokość nie przekracza 16 % wysokości ekranu; wiersz tożsamości mieści nazwę,
  odznakę i podpis (rozszerzenie testu przeglądowego z fali pierwszej); populacji nie ma
  w pasku, a jest w widoku osady.
- **Gęstość**: `gap()` skaluje przez oba mnożniki i zaokrągla; dla dodatniej wartości i gęstości
  poniżej jedynki wynik jest nie większy niż `px()`; `flat()` bierze marginesy z `gap()`,
  a promień i obramowanie z `px()` — ten przypina samą zasadę podziału.
- **Geometria mapy**: dla próbki sąsiednich par wysp ich wielokąty wody przybrzeżnej, te same,
  które rysuje `IslandGenerator`, poszerzone o połowę minimalnego prześwitu, nie przecinają się;
  `island_offset` jest deterministyczne i mieści się w `OFFSET_RANGE`; dysk trafienia w najgorszym
  przypadku mieści się we własnej komórce; tapnięcie liczy od przesuniętego środka; prostokąty
  etykiet dwóch sąsiednich osad nie przecinają się.
- **Czytelność**: karta produkowana ma tło `PARCHMENT`, ikonę w kolorze zasobu i niepuste tempo;
  nieprodukowana ma `VELLUM`, liczbę i ikonę `INK_SOFT` oraz puste tempo; żadna karta nie jest przyciemniana
  przezroczystością (`modulate.a == 1.0`); `Icon.knockout` ma domyślną wartość i ustawiona
  wartość dochodzi do rysowania.
- **Kontrakt położenia**: `island_offset` odtwarza wzór z ADR 0001, punkt 8, dla znanych komórek
  (złote wartości policzone niezależnie). Artefakt `contract/world-parity.json` (9,6 MB, czytany
  tylko przez backend) dostaje `offsetX` i `offsetY` każdej komórki lądu; przy regeneracji
  niezależna implementacja wzoru w Pythonie porównuje wszystkie komórki lądu obu ziaren, a każde
  dotychczasowe pole musi zostać bit w bit identyczne. Stałego testu klienta na artefakcie nie ma,
  bo parsowanie go w każdym przebiegu testów jest zbyt kosztowne.
- **Odległość podróży**: przy zerowym przesunięciu `SeaNavigation.distance` daje dzisiejszą
  odległość między komórkami; przy przesunięciu liczy między położeniami; jest symetryczna;
  kierunek wiatru liczy się po tym samym wektorze.
- **Tapnięcie**: tapnięcie własnej osady, także aktywnej, otwiera arkusz oglądanej wyspy i nie
  zmienia osady aktywnej; „Przejdź do osady” zmienia osadę aktywną i przełącza widok; „Wróć do
  osady” tylko przełącza widok.
- **Pseudonim**: `ownerName` jest czytany przez osadę i flotę; trzy miejsca wyświetlania pokazują
  pseudonim, a nigdy numeryczny identyfikator; własna osada pokazuje „Ty”.
- **Weryfikacja wizualna**: `tools/capture_probe.gd` przy oknie równym viewportowi, po każdej
  sekcji. Raportuje wysokość paska w procentach i szerokości wszystkich etykiet, więc pilnuje
  budżetu z 3.2 i klasy błędu z fali pierwszej.

## 10. Sekcje UI v2 do zaktualizowania

Po wdrożeniu poprzedni spec wymaga korekt w: 3.4 (widok osady zyskuje populację), 3.5 (warstwa
UI mapy, ikona zamiast plakietki z napisem, `ZOOM_MIN`, tapnięcie zawsze ogląda), 4.2 (`px()`
kontra `gap()`), 4.3 (ikona kamienia, kolor wycięcia), 5 (struktura paska, budżet wysokości,
usunięte węzły, stan karty nieprodukowanej), 7 (tryb własnej osady w arkuszu, pseudonim
w podpisie) oraz w tabeli decyzji (placeholder złota, przyciemnianie kart, zasada o grafikach).
Do tego sekcja 6.4, która wciąż nazywa węzeł `ModalBody`, przemianowany na `Body` jeszcze
w poprzedniej fali.

Poza specyfikacją UI v2: specyfikacja szkieletu klienta, sekcja 4.2 (dane publiczne osady
zawierają pseudonim) i `docs/architecture/data-flow.html`, który ta fala dezaktualizuje w pasku,
grupach, sygnałach i polach kontraktu.

## 11. Kolejność implementacji

1. `MedievalTheme.DENSITY` i `gap()`, z przeniesieniem odstępów w motywie; testy zasady podziału.
2. Przeniesienie odstępów na `gap()` w pasku, arkuszach, doku i warstwie UI mapy.
3. Przebudowa paska na dwa wiersze; populacja do widoku osady; testy budżetu i tożsamości.
4. `Icon.knockout` i ikona kamienia; ustawienie wycięcia w nagłówkach, doku i chipach.
5. Czytelność kart zasobów; usunięcie `DIMMED`.
6. `CELL_SIZE`, `ZOOM_MIN`, stałe `FleetRenderer`; testy niezmiennika prześwitu.
7. `island_offset` i `island_center`; rozmieszczanie, pierścienie, etykiety, trafianie,
   `Fleet.position_at` z ziarnem; testy trafiania i etykiet.
8. Ikona powrotu na mapie zamiast plakietki z napisem.
9. `island_position` i wzór z kontraktu; `SeaNavigation` na położeniach; przegenerowanie
   `contract/world-parity.json` z `offsetX` i `offsetY`.
10. Tapnięcie zawsze ogląda; tryb własnej osady w `InspectSheet` z akcją przejścia.
11. `ownerName` w osadzie, flocie, fixtures i trzech miejscach wyświetlania.
12. Aktualizacja sekcji z listy 10 i dokumentu architektury; przegląd wizualny sondą i przez
    człowieka; strojenie `DENSITY` i `ZOOM_MIN` osobnym commitem.
