# Islanders – UI v2, korekty po przeglądzie na urządzeniu

Data: 2026-09-09
Status: zatwierdzony w brainstormingu, czeka na plan implementacji
Poprzedni spec: `2026-09-08-islanders-ui-v2-design.md`. Ten dokument go nie zastępuje; nadpisuje
sekcje 3.3, 3.4, 3.5, 5 i 6.1 oraz decyzje o placeholderze złota i o przyciemnianiu kart.

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

Poza zakresem: zmiana promieni zaokrągleń i wyłączanie wygładzania krawędzi (renderowanie jest
obiektywnie ostre), zmiana promieni wysp (należą do kontraktu parytetu), nowa waluta w miejsce
usuwanego placeholdera złota.

## 2. Decyzje

| Decyzja | Wybór | Uzasadnienie |
|---|---|---|
| Wysokość paska | Dwa wiersze, cel ~14 %, próg testowy 16 % | Wybór właściciela z trzech wariantów; tempo produkcji zostaje, populacja się przenosi |
| Populacja | Przenosi się do widoku osady | Dotyczy osady aktywnej; rekrutacja i wysyłanie flot startują z osady |
| Placeholder złota | Usuwany | Pokazuje zero i nie jest z niczym połączony; zajmuje szerokość potrzebną wierszowi tożsamości |
| Awatar kotwicy | Usuwany | Statyczny glif bez informacji, 111 px szerokości |
| Gęstość odstępów | Jedno pokrętło `DENSITY` niezależne od `SCALE` | Zagęszcza cały interfejs bez zmniejszania tekstu i ikon; jedna liczba do korekty po ocenie na urządzeniu |
| Rozsunięcie wysp | `CELL_SIZE` 256 → 448 | Nie należy do kontraktu parytetu, więc backend nietknięty |
| Rozbicie siatki | Deterministyczne przesunięcie środka w obrębie komórki | Wyspy przestają czytać się jako rzędy; zakres wyliczony z warunku nienachodzenia |
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

`WorldGrid.CELL_SIZE` z 256 na 448. Kontrakt parytetu (`contract/world-parity.json`) opisuje
częstotliwości szumu, próg lądu, promienie, szansę znaleziska i kolejność zasobów; rozmiaru
komórki tam nie ma, bo backend pracuje w komórkach. Artefakt kontraktu nie wymaga przegenerowania.

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
## Przesunięcie środka wyspy w obrębie komórki, żeby wyspy nie stały w równych rzędach.
## Deterministyczne z ziarna i komórki, z hasha innego niż lądowy, biomowy, promieniowy
## i znaleziskowy, żeby nie korelowało z żadnym z nich.
const OFFSET_RANGE := 0.13   ## ułamek komórki w każdą stronę
static func island_offset(world_seed: int, cell: Vector2i) -> Vector2
static func island_center(world_seed: int, cell: Vector2i) -> Vector2
```

Zakres wyliczony z warunku, nie dobrany na oko:

| Krok | Wartość |
|---|---|
| Najgorsza para promieni | 110 + 110 |
| Woda przybrzeżna, skala 1,18 | 260 px |
| Docelowy minimalny prześwit | 60 px |
| Wymagana odległość środków | ≥ 320 px |
| Maksymalne przesunięcie przy komórce 448 | 64 px, czyli 0,143 komórki |
| Przyjęte `OFFSET_RANGE` | 0,13, czyli do 58 px |
| Najgorsza odległość środków | 448 − 116 = 332 px |
| Najgorszy prześwit | 332 − 260 = 72 px |

### 5.3 Trafianie w wyspę i pozycje

Tapnięcie sprawdza komórkę tapniętą i osiem sąsiednich, i wybiera najbliższą wyspę, której
przesunięty środek mieści się w promieniu trafienia. Sąsiedzi są konieczni, bo po przesunięciu
wyspa z sąsiedniej komórki może być bliżej niż wyspa z komórki tapniętej.

Tej samej przesuniętej pozycji używają: rozmieszczanie generatorów wysp w chunkach, pierścienie
osad, etykiety osad oraz trasy flot.

`Fleet.position_at(now)` dostaje drugi parametr `world_seed: int`, bo flota zna identyfikator
świata, ale nie jego ziarno. Bez tego linia trasy kończyłaby się obok wyspy, a nie na niej.
Konsumenci do poprawki: `FleetRenderer` i skok kamery po tapnięciu karty floty w `Sheets`.

### 5.4 Dwie usterki ze zgłoszonego zrzutu

**Nachodzące etykiety osad** rozwiązują się skutkiem 5.1: etykieta ma 240 px szerokości, a
najmniejsza możliwa odległość środków to 332 px, więc nałożenie jest niemożliwe. Test przypina
ten stan, żeby nie wrócił.

**Plakietka „OSADA” zasłaniająca wyspę** schodzi do samej ikony w kwadracie `px(46)`, spójnie
z przyciskami doku i przybliżania. Napis jest zbędny przy strzałce powrotu, a plakietka przestaje
zajmować `px(110)` szerokości mapy.

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

## 7. Zmiany interfejsu i konsumenci

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

## 8. Testy

- **Pasek**: wysokość nie przekracza 16 % wysokości ekranu; wiersz tożsamości mieści nazwę,
  odznakę i podpis (rozszerzenie testu przeglądowego z fali pierwszej); populacji nie ma
  w pasku, a jest w widoku osady.
- **Gęstość**: `gap()` skaluje przez oba mnożniki i zaokrągla; dla dodatniej wartości i gęstości
  poniżej jedynki wynik jest nie większy niż `px()`; `flat()` bierze marginesy z `gap()`,
  a promień i obramowanie z `px()` — ten przypina samą zasadę podziału.
- **Geometria mapy**: dla próbki sąsiednich par zajętych komórek odległość przesuniętych środków
  jest nie mniejsza niż woda przybrzeżna obu wysp (niezmiennik, nie konkretne liczby);
  `island_offset` jest deterministyczne i mieści się w `OFFSET_RANGE`; trafianie znajduje wyspę
  z komórki sąsiedniej, gdy przesunięcie ją przybliżyło; prostokąty etykiet dwóch sąsiednich
  osad nie przecinają się.
- **Czytelność**: karta produkowana ma tło `PARCHMENT`, ikonę w kolorze zasobu i niepuste tempo;
  nieprodukowana ma `VELLUM`, liczbę i ikonę `INK_SOFT` oraz puste tempo; żadna karta nie jest przyciemniana
  przezroczystością (`modulate.a == 1.0`); `Icon.knockout` ma domyślną wartość i ustawiona
  wartość dochodzi do rysowania.
- **Weryfikacja wizualna**: `tools/capture_probe.gd` przy oknie równym viewportowi, po każdej
  sekcji. Raportuje wysokość paska w procentach i szerokości wszystkich etykiet, więc pilnuje
  budżetu z 3.2 i klasy błędu z fali pierwszej.

## 9. Sekcje UI v2 do zaktualizowania

Po wdrożeniu poprzedni spec wymaga korekt w: 3.3 (dok, ikona zamiast plakietki z napisem),
3.4 (widok osady zyskuje populację), 3.5 (warstwa UI mapy, `ZOOM_MIN`), 5 (struktura paska,
budżet wysokości, usunięte węzły), 6.1 (`px()` kontra `gap()`) oraz w tabeli decyzji
(placeholder złota, przyciemnianie kart). Do tego sekcja 6.4, która wciąż nazywa węzeł
`ModalBody`, przemianowany na `Body` jeszcze w poprzedniej fali.

## 10. Kolejność implementacji

1. `MedievalTheme.DENSITY` i `gap()`, z przeniesieniem odstępów w motywie; testy zasady podziału.
2. Przeniesienie odstępów na `gap()` w pasku, arkuszach, doku i warstwie UI mapy.
3. Przebudowa paska na dwa wiersze; populacja do widoku osady; testy budżetu i tożsamości.
4. `Icon.knockout` i ikona kamienia; ustawienie wycięcia w nagłówkach, doku i chipach.
5. Czytelność kart zasobów; usunięcie `DIMMED`.
6. `CELL_SIZE`, `ZOOM_MIN`, stałe `FleetRenderer`; testy niezmiennika prześwitu.
7. `island_offset` i `island_center`; rozmieszczanie, pierścienie, etykiety, trafianie,
   `Fleet.position_at` z ziarnem; testy trafiania i etykiet.
8. Ikona powrotu na mapie zamiast plakietki z napisem.
9. Aktualizacja sekcji poprzedniego specu z listy 9; przegląd wizualny sondą i przez człowieka.
