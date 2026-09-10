---
name: updating-architecture-doc
description: Use when changes in the Islanders Godot client (signals, connect() calls, scenes or nodes, CanvasLayers, groups, autoloads, .gd/.tscn files, API endpoints or JSON fields, _process loops, timers) may have made docs/architecture/data-flow.html stale, or when asked to update, refresh or verify the architecture / data-flow document ("zaktualizuj dokument architektury", "przepływ danych", "drzewo węzłów").
---

# Aktualizowanie dokumentu architektury

`docs/architecture/data-flow.html` opisuje klienta w stanie z commita podanego w nagłówku („Stan na”). Aktualizacja to przeniesienie do dokumentu różnicy kodu od tego commita, a potem dowód skryptem i renderem, że plik dalej działa.

## Kroki

1. **Zakres z gita, nie z pamięci.** Hash H: `grep -o 'Stan na: <b>[0-9a-f]*' docs/architecture/data-flow.html`. Potem `git log --oneline H..HEAD` i `git diff H..HEAD -- scenes scripts tools project.godot fixtures` (plus `git status` dla zmian niezacommitowanych). Czytaj diff.
2. **Lista kontrolna ze skryptu:** `python3 .agents/skills/updating-architecture-doc/check_doc.py [ścieżka.html]` (domyślnie plik z repo). Brakujące pliki i sygnały to szkielet pracy.
3. **Szerokości przed edycją:** wyrenderuj dokument (sekcja „Render”) i zapisz `[...document.querySelectorAll('.mm svg')].map(s => s.style.maxWidth)`. Posłuży do wykrycia „schodów” po zmianach.
4. **Nanieś zmiany** według tabeli niżej.
5. **Nagłówek i historia:** „Stan na” = `git rev-parse --short HEAD` · `git log -1 --format=%cs`. Dopisz wiersz w `#historia` z tym hashem i jednym zdaniem o zmianie.
6. **Weryfikacja:** skrypt kończy się kodem 0, a render przechodzi.

## Co gdzie

| Zmiana w kodzie | Miejsce w dokumencie |
|---|---|
| Nowy, usunięty albo przemianowany `.gd`/`.tscn` | Tablica `FILES` (sekcja `#pliki`); węzeł w scenie — też tablica `TREE` |
| Plik zaczyna albo przestaje używać innego | Pole `u` („Używa”) i `k` („API”) istniejących wpisów `FILES` |
| Sygnał albo `connect()` | Diagram `#sygnaly` (pigułka i strzałki) oraz tabela sygnałów |
| Bezpośrednie wywołanie między węzłami | Tabela „Bezpośrednie wywołania” w `#sygnaly` |
| Węzeł, scena, CanvasLayer, grupa | `TREE`; nowy CanvasLayer — też „Stos warstw” w `#wezly` |
| Endpoint, pole JSON, provider | `#dane` (diagram i reguły walidacji) oraz `#warstwy` |
| Nowy przepływ gracza | Nowa sekwencja w `#interakcje` |
| Nowy wyzwalacz resync, `_process`, Timer, tween | `#czas`: diagram resync albo tabela „Co dzieje się w każdej klatce” |
| Domknięty albo nowy placeholder | Wiersz w `#luki` |
| `WorldGrid` / geografia | `#geografia` i wzmianka o `contract/world-parity.json` |

Po zmianach przeczytaj teksty wstępne (`.lead`) zmienionych sekcji. Liczebniki („trzy ścieżki”) i przykłady („np. wysyłanie floty”) łatwo zostają nieaktualne.

Typy węzłów do `TREE` bierz z linii `[node … type=…]` w `.tscn`, a dla węzłów tworzonych w kodzie — z `X.new()`. Czego diff nie mówi (klucze JSON, kto woła, rozmiar arkusza), tego nie zgaduj: napisz ogólniej albo zapytaj użytkownika.

Niespójności w kodzie zauważone przy okazji (np. sygnał z argumentem podpięty do metody bez argumentów) zgłoś użytkownikowi w odpowiedzi. Nie naprawiaj ich w ramach aktualizacji dokumentu.

## Mermaid: reguły, które łamią render albo układ

- Kolory nadajesz tylko liniami `class A,B core`. Dostępne klasy: `data api state core view ui tool sig ghost`. Nigdy nie wpisuj `classDef` — definiuje je `CLASSDEFS` w skrypcie strony, osobno dla trybu jasnego i ciemnego.
- Etykiety zawsze w cudzysłowie: `A["…"]`. Bez znaków `;` `#` `&` i `<` (poza `<br/>`). Etykiety węzłów łam przez `<br/>` co 3–4 słowa.
- Tylko krawędzie w przód i nigdy do identyfikatora subgrafu — jedno i drugie zamienia diagram w „schody”. Drogę powrotną opisz w tabeli albo tekście. Węzły ułożysz w kolumnę przez `A ~~~ B`.
- Tytuły subgrafów krótkie (1–3 słowa), bo dłuższe są ucinane.
- Sygnał w `#sygnaly` to pigułka `id(["nazwa(args)"])` z `class id sig`: emiter → pigułka → odbiorca, a na strzałce metoda.
- W sekwencjach `Note over A,B` ma szerokość swoich uczestników. Dłuższy tekst łam przez `<br/>`, bo inaczej wychodzi poza ramkę.

## Render

1. Playwright blokuje `file://`, więc uruchom w tle: `python3 -m http.server 8765 --bind 127.0.0.1 --directory docs/architecture` i otwórz `http://127.0.0.1:8765/data-flow.html`.
2. Po około 3 s sprawdź: `document.querySelectorAll('.mm svg').length === document.querySelectorAll('pre.mermaid').length` oraz brak `.mm .err`.
3. Porównaj szerokości z kroku 3. Diagram szerszy o ponad ~30% przy małej zmianie to prawie zawsze krawędź wsteczna albo krawędź do subgrafu.
4. Każdy zmieniony diagram obejrzyj w trybie pełnoekranowym (przycisk ⤢ w jego ramce, oddalanie przyciskiem −) — w zwykłym widoku szeroki diagram jest przycięty przewijaniem. Zrób to też po kliknięciu `#themeBtn` (tryb ciemny).
5. Zrzuty zapisuj jako `.playwright-mcp/nazwa.png`, żeby trafiły do folderu usuwanego w kroku 7. Sama nazwa pliku (bez folderu) zapisuje PNG w katalogu głównym repo.
6. W konsoli pojawiają się błędy Mermaid `translate(undefined, NaN)` przy krawędziach bez etykiet. To znany szum — ignoruj.
7. Na koniec zatrzymaj serwer, zamknij przeglądarkę i usuń `.playwright-mcp/`. `git status` ma pokazywać tylko zmiany w dokumencie.

Jeśli nie masz Playwrighta, poproś użytkownika o otwarcie pliku i sprawdzenie, czy żaden diagram nie pokazuje „Błąd w diagramie”.

## Częste błędy

| Błąd | Skutek | Poprawka |
|---|---|---|
| Krawędź wsteczna albo do subgrafu | Diagram rozlany po skosie, 2–3× szerszy | Tylko krawędzie w przód, reszta w tabeli |
| `classDef` w diagramie | Kolor nie zmienia się w trybie ciemnym | Linia `class A core` |
| Zakres z opisu zmiany zamiast z diffu | Pominięte pliki i sygnały | `git diff H..HEAD` i skrypt |
| Nowy wpis w `FILES`, ale stare pola „Używa” bez zmian | Katalog kłamie o zależnościach | Wiersz „Plik zaczyna albo przestaje używać” w tabeli |
| Stary hash w „Stan na” albo brak wiersza w historii | Następna aktualizacja startuje od złego commita | Krok 5; skrypt to wyłapuje |
| Zrzut bez prefiksu `.playwright-mcp/` | PNG w katalogu głównym repo | Krok 5 w „Render” |
