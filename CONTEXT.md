# Islanders

Mobilna gra MMO RTS w scenerii archipelagu. Gracze rozwijają wyspy, wydobywają zasoby i wysyłają floty między wyspami na wspólnej mapie świata.

## Language

### Świat

**World** (świat):
Odrębna instancja gry z własnym seedem, granicami mapy, wiatrem i rundą. Wyspy, osady i floty należą zawsze do jednego świata; gracz może mieć profil na wielu światach.
_Avoid_: server, realm, shard, map, round

**Round** (runda):
Okres życia świata od otwarcia do spełnienia warunku zwycięstwa. Świat `OPEN` przyjmuje nowych graczy, `CLOSED` już nie, ale gra trwa, a `ENDED` można tylko oglądać; konto gracza trwa dłużej niż jego osady na zakończonym świecie.
_Avoid_: season, era, game, match

**Cell** (komórka):
Pojedyncze pole siatki świata o współrzędnych całkowitych `(x, y)`. Komórka jest albo morzem, albo zawiera dokładnie jedną wyspę.
_Avoid_: tile, pole, pozycja

**Island** (wyspa):
Ląd zajmujący jedną komórkę. Tożsamością wyspy jest para świat i współrzędne komórki `(x, y)`; wyspa nie ma osobnego identyfikatora liczbowego. Kształt, biom i położenie wyspy w obrębie jej komórki wynikają deterministycznie z seeda świata i współrzędnych.
_Avoid_: island id, landmass, tile

### Zasoby

**Resource** (zasób):
Jeden z pięciu surowców: `wood`, `stone`, `food`, `iron`, `sulfur`. Każdy zasób jest produkowany tylko w biomach, do których należy; poza nimi można go zdobyć wyłącznie z pakietu startowego, wypraw, handlu lub podboju.
_Avoid_: material, raw, currency, good

**Biome** (biom):
Typ wyspy decydujący o wyglądzie i o tym, które zasoby można na niej produkować: `TROPICAL` (wood, food), `TEMPERATE` (stone, food), `VOLCANIC` (iron, sulfur).
_Avoid_: terrain, climate, island type

**Capacity** (pojemność):
Górny limit każdego zasobu w osadzie, wynikający z poziomu Warehouse, jednakowy dla wszystkich zasobów. Produkcja zatrzymuje się na limicie, a nadwyżka z produkcji lub rozładunku floty przepada.
_Avoid_: storage cap, max resources, warehouse limit

**Starter Pack** (pakiet startowy):
Zasoby, które nowa osada otrzymuje przy założeniu, żeby gracz mógł budować, zanim zdobędzie brakujące surowce z innych biomów.
_Avoid_: initial resources, bonus, welcome gift

### Osadnictwo

**Deposit** (znalezisko):
Zapas zasobów na wyspie niczyjej (wrak, opuszczona kopalnia, porzucony magazyn), wynikający deterministycznie z seeda. Cel wypraw; nie istnieje na morzu.
_Avoid_: shipwreck, loot, treasure, resource node, spawn

**Settlement** (osada):
Stan gracza na konkretnej wyspie: właściciel, nazwa, zasoby, budynki, populacja. Wyspa ma co najwyżej jedną osadę; wyspa bez osady jest niczyja i nie produkuje niczego.
_Avoid_: colony, village, base, island state, placeholder

**Building** (budynek):
Struktura w osadzie z poziomem od 0 wzwyż. Budynki wspólne: `TOWN_HALL`, `BARRACKS`, `SHIPYARD`, `WAREHOUSE`. Budynki wydobywcze, każdy związany z jednym zasobem i dostępny tylko w biomach tego zasobu: `SAWMILL`, `QUARRY`, `FARM`, `IRON_MINE`, `SULFUR_PIT`.
_Avoid_: structure, facility, upgrade

**Slot** (slot):
Stałe miejsce na wyspie przypisane do jednego typu budynku. Każda osada ma sześć slotów: cztery wspólne i dwa wydobywcze wynikające z biomu. Slot z budynkiem na poziomie 0 jest pusty.
_Avoid_: plot, lot, building spot, tile

**Population** (populacja):
Miejsca zajęte przez statki i jednostki należące do osady (w garnizonie i we flotach) wobec limitu wynikającego z budynków. Nie jest zasobem, nie rośnie w czasie i nie konsumuje jedzenia.
_Avoid_: citizens, people, workers, pop resource

**Home Settlement** (osada domowa):
Osada profilu, od której gra zaczyna się po uruchomieniu. Zakładana przez serwer przy dołączeniu do świata; po jej utracie serwer wskazuje najstarszą pozostałą osadę, a profil bez osad nie ma osady domowej.
_Avoid_: capital, main base, starting island

### Perspektywa gracza

**Player** (gracz):
Konto uczestnika gry, trwające ponad światami. Na każdym świecie, do którego dołączył, ma dokładnie jeden profil.
_Avoid_: user, account, owner

**Profile** (profil):
Obecność gracza na jednym świecie: data dołączenia i osada domowa. Osady, garnizony i floty należą do gracza w ramach jego profilu na danym świecie.
_Avoid_: world player, membership, member, session

**Nickname** (pseudonim):
Publiczna, unikalna nazwa gracza, widoczna dla wszystkich jako właściciel osady. Jedyna informacja o koncie, jaką widzą inni gracze.
_Avoid_: username, display name, login, handle

**Active Settlement** (osada aktywna):
Osada gracza, w kontekście której działa interfejs: jej zasoby widać w HUD i z niej wysyła się floty. Zawsze należy do gracza i zmienia się tylko przez świadome przełączenie, nigdy przez samo obejrzenie wyspy.
_Avoid_: selected island, current island, focused settlement

**Inspected Island** (oglądana wyspa):
Wyspa, którą gracz aktualnie ogląda po wybraniu na mapie. Może być własna, cudza lub niczyja; dla cudzej widoczne są tylko dane publiczne.
_Avoid_: selected island, target, clicked island

**Public Data** (dane publiczne):
To, co każdy gracz widzi o każdej wyspie: geografię, biom, znalezisko, a dla osady nazwę i właściciela. Zasoby, budynki, garnizon i floty osady są prywatne dla jej właściciela.
_Avoid_: visible info, fog of war, intel

**Incoming Fleet** (nadchodząca flota):
Cudza flota, której celem jest osada gracza. Jedyny przypadek, w którym gracz widzi cudzą flotę w drodze: jej właściciela, misję, trasę i czasy wypłynięcia i przybycia, nigdy statków ani ładunku.
_Avoid_: attack warning, threat, enemy movement

### Floty

**Fleet** (flota):
Grupa statków w jednokierunkowej podróży między dwiema wyspami, z czasem wypłynięcia i przybycia. Może przewozić jednostki i zasoby. Celem floty jest zawsze wyspa, niezależnie od tego, czy ma osadę. Po przybyciu flota przestaje istnieć; ewentualny powrót to nowa flota.
_Avoid_: armada, convoy, movement, expedition

**Ship** (statek):
Jednostka pływająca. W porcie należy do garnizonu osady, w ruchu należy do floty.
_Avoid_: vessel, boat, naval unit

**Unit** (jednostka):
Jednostka lądowa. Stacjonuje w garnizonie osady albo jest przewożona przez flotę; nigdy nie porusza się po mapie samodzielnie.
_Avoid_: troop, soldier, army

**Garrison** (garnizon):
Wszystkie statki i jednostki stacjonujące w osadzie, czyli wojsko „w domu” w odróżnieniu od floty „w drodze”.
_Avoid_: army, port, home fleet, stationed units

**Cargo** (ładunek):
Jednostki i zasoby przewożone przez flotę.
_Avoid_: payload, transport, load

**Mission** (misja):
Powód wysłania floty, decydujący o tym, co dzieje się po przybyciu: `COLONIZE`, `ATTACK`, `TRANSPORT`, `EXPEDITION`, `RETURN`. Flotę z misją `RETURN` tworzy wyłącznie serwer, gdy po rozstrzygnięciu misji coś ma wrócić do osady.
_Avoid_: order, command, action, fleet type

**Wind** (wiatr):
Jeden wektor dla całego świata, zmieniany okresowo przez serwer. Wpływa na czas podróży floty wyłącznie w chwili wypłynięcia; wypłynięta flota ma czas przybycia zamrożony.
_Avoid_: weather, current, wind field

**Travel Time** (czas podróży):
Czas między wypłynięciem a przybyciem floty, wyliczany raz przy wypłynięciu z odległości między położeniami wysp, prędkości najwolniejszego statku i wiatru.
_Avoid_: ETA, duration, flight time

**Settler** (osadnik):
Jednostka rekrutowana w Town Hall, wymagana i zużywana przy założeniu nowej osady.
_Avoid_: colonist, colony ship, pioneer

**Colonization** (kolonizacja):
Założenie osady na wyspie niczyjej przez flotę z misją `COLONIZE` wiozącą osadnika. Nowa osada otrzymuje pakiet startowy oraz ładunek floty; znalezisko na tej wyspie przestaje istnieć. Jeśli wyspa jest już zajęta w chwili przybycia, flota wraca.
_Avoid_: settling, claiming, founding, expansion

**Expedition** (wyprawa):
Flota z misją `EXPEDITION`: leci na wyspę niczyją, zabiera część znaleziska i wraca do osady macierzystej.
_Avoid_: raid, scavenge, gather, farming
