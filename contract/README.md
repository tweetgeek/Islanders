# contract/world-parity.json

Ten plik jest kontraktem geografii klient-serwer z ADR 0001
(`docs/adr/0001-deterministic-world-geography.md`) i sekcji 4 `api-guidelines.md` w
`IslandersAPI`. Zawiera zrzut tego, co `WorldGrid` (`scripts/core/WorldGrid.gd`) produkuje dla
kilku ziaren świata na siatce co najmniej 200 × 200 komórek: dla każdej komórki `hash`, `land`
i `biome` (surowe wartości szumu), a dla komórek będących wyspami dodatkowo `radius` i
`deposit`. Wszystkie liczby zmiennoprzecinkowe są zapisane z pełną precyzją IEEE 754 (17 cyfr
po przecinku) - nie zaokrąglone, bo zaokrąglenie ukryłoby dokładnie ten dryf między klientem
a backendem, który ten plik ma wykrywać.

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
