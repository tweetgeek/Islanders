# contract/world-parity.json

Ten plik jest kontraktem geografii klient-serwer z ADR 0001
(`docs/adr/0001-deterministic-world-geography.md`) i sekcji 4 `api-guidelines.md` w
`IslandersAPI`. Zawiera zrzut tego, co `WorldGrid` (`scripts/core/WorldGrid.gd`) produkuje dla
kilku ziaren świata na siatce co najmniej 200 × 200 komórek: dla każdej komórki `hash`, `land`
i `biome` (surowe wartości szumu), a dla komórek będących wyspami dodatkowo `radius` i
`deposit`. Wszystkie liczby zmiennoprzecinkowe są zapisane z pełną precyzją IEEE 754 - siedemnaście
cyfr ZNACZĄCYCH (nie miejsc po przecinku - to nie to samo, patrz niżej) - nie zaokrąglone do
mniejszej precyzji, bo zaokrąglenie ukryłoby dokładnie ten dryf między klientem a backendem,
który ten plik ma wykrywać.

**Dowód odwracalności zapisu.** `tools/world_parity_dump.gd` przed zapisaniem KAŻDEJ liczby
dowodzi arytmetyką całkowitoliczbową (nie parsowaniem łańcucha z powrotem przez silnik - Godot
4.8.dev4 ma udokumentowany w historii tej naprawy błąd o 1 ULP w `String.to_float()` /
`JSON.parse_string()` / `str_to_var()`, który fałszywie alarmowałby na ok. 15-26% poprawnych
wartości), że zapisany łańcuch jest bliżej oryginalnej wartości `double` niż jakiejkolwiek innej
reprezentowalnej liczbie zmiennoprzecinkowej. Jeśli ten dowód się nie zgadza, narzędzie przerywa
przez `assert()` zamiast po cichu zapisać plik, który kłamie. **Ktokolwiek regeneruje ten plik,
musi potwierdzić, że ten dowód przeszedł** (czyli że `./run_parity.sh` zakończył się kodem 0,
bez `SCRIPT ERROR: Assertion failed`) - to jest właściwy sygnał, że zapis jest wiarygodny, nie
sam fakt, że plik powstał. Z tego samego powodu każdy konsument porównujący się z tym plikiem
(w tym test parity w backendzie NestJS) MUSI używać **równości dokładnej**, nigdy tolerancji/
epsilona - tolerancja ukryłaby dokładnie ten dryf ostatnich bitów, który ten plik ma wykrywać.

Backend NestJS ma test, który czyta ten sam plik i sprawdza swoją implementację `WorldGrid`
komórka po komórce. To ważniejszy test niż jakikolwiek inny w backendzie: bez niego rozjazd
między klientem a serwerem wyszedłby dopiero wtedy, gdy gracz zobaczyłby swoją osadę na morzu.

## Regeneracja

```
./run_parity.sh
```

Uruchamia `tools/world_parity_dump.gd` i nadpisuje `contract/world-parity.json`. Uruchamianie
tego narzędzia bez żadnej zmiany w `WorldGrid.gd` musi dać bit-identyczny plik - jeśli nie daje,
generator albo `WorldGrid` mają niedeterminizm, którego nie powinno tu być.

## Co oznacza zmiana tego pliku

Ten plik nie jest artefaktem tymczasowym ani danymi testowymi do odświeżenia przy okazji.
Jeżeli po zmianie w `WorldGrid.gd` (albo w jego odpowiedniku w NestJS) zawartość tego pliku się
zmienia, to znaczy, że **zmieniła się geografia świata** - inne komórki są lądem, inne wyspy mają
inny promień albo inne znalezisko. Każdy istniejący, otwarty świat trzeba by wtedy zmigrować
(patrz ADR 0001, sekcja "Konsekwencje"): zmiana algorytmu geografii po otwarciu świata to
migracja całego świata, nie zwykły redeploy. Nie aktualizuj tego pliku odruchowo, żeby test
przeszedł - jeśli test go przypina i się nie zgadza, to sygnał, że kontrakt klient-serwer się
rozjechał, a nie że plik trzeba "odświeżyć".
