---
status: accepted
---
# Geografia świata liczona deterministycznie z seeda, wyspa identyfikowana przez współrzędne

Mapa świata w grze typu Tribal Wars jest stała, zmienia się tylko stan osad. Zamiast trzymać wyspy jako rekordy z własnym `id` i serwować geometrię przez API, istnienie, kształt, biom i znalezisko każdej wyspy wynikają deterministycznie z `worldSeed` i współrzędnych komórki `(x, y)` przez `FastNoiseLite` i hash. Klient rysuje całą mapę bez requestów, a tożsamością wyspy jest `(worldId, x, y)`; serwer przechowuje tylko osady (stan gracza) pod tym samym kluczem.

## Konsekwencje

- Algorytm placementu i kształtu jest częścią kontraktu klient–serwer; zmiana po otwarciu świata to migracja całego świata. Backend NestJS musi mieć identyczną implementację `WorldGrid` (ten sam szum, ten sam hash).
- Mgła wojny na poziomie geografii jest niemożliwa, bo klient zna wszystkie wyspy; tajemnicą pozostaje wyłącznie stan osad.
- Nowy rodzaj celu floty na komórce morza wymagałby rozszerzenia siatki o trzeci stan komórki, czego celowo nie robimy.

## Odrzucone alternatywy

- Serwer jako jedyne źródło geometrii (`GET /world?chunk=`): mapa „skacze” przy przewijaniu, mock musi udawać cały świat, algorytm i tak trzeba by napisać po stronie serwera.
- Serwerowe `id` liczbowe obok współrzędnych: dwa klucze dla jednego bytu, rozjazdy między klientem znającym `(x, y)` a serwerem znającym `id`.
