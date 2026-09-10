---
status: accepted
---
# Położenie wyspy w obrębie komórki jest częścią geografii i wyznacza odległość podróży

Środek każdej wyspy jest przesunięty w obrębie swojej komórki o deterministyczny wektor wyliczony z `worldSeed` i współrzędnych, w zakresie ±0,13 komórki na każdej osi. To przesunięcie należy do kontraktu geografii z ADR 0001, a czas podróży floty liczy się z odległości między tak przesuniętymi położeniami wysp, nie między komórkami. Chcieliśmy, żeby mapa wyglądała organicznie, a nie jak siatka, i jednocześnie nie kłamała: odległość, którą gracz widzi na mapie, jest odległością, którą płynie flota.

## Odrzucone warianty

- **Odległość w komórkach, przesunięcie tylko wizualne (±0,13).** Mapa organiczna, ale nieuczciwa: dwie wyspy po przekątnej mogą wyglądać na bliższe (1,05 komórki) niż sąsiedzi w poziomie (1,26), a płynie się do nich o 41 % dłużej. W grze, w której cel ataku wybiera się okiem z mapy, to wprowadza gracza w błąd.
- **Odległość w komórkach, przesunięcie zmniejszone do ±0,085.** Najmniejsze przesunięcie, przy którym kolejność odległości między bezpośrednimi sąsiadami nie może się odwrócić. Uczciwsze, ale siatka rozbija się ledwie widocznie, a rozbieżność między linią trasy a czasem przybycia zostaje (±17 % dla sąsiadów).
- **Bez przesunięcia, tylko większa komórka.** W pełni wierna i najprostsza, ale wyspy nadal stoją w równych rzędach, co było jednym z czterech zgłoszonych zarzutów.

## Konsekwencje

- Przesunięcie jest wyrażone w ułamkach komórki, nie w pikselach, więc backend nie musi znać `CELL_SIZE`, który pozostaje stałą renderingową klienta. Dokładny wzór: ADR 0001, Załącznik, punkt 8.
- `OFFSET_RANGE = 0.13` jest zamrożoną stałą rozgrywki, jak `LAND_THRESHOLD`: zmiana po otwarciu świata zmienia czasy podróży każdej floty, więc jest migracją świata.
- Odległość między bezpośrednimi sąsiadami w poziomie waha się od 0,74 do 1,26 komórki. To celowa cecha mapy: położenie wyspy ma znaczenie, są położenia lepsze i gorsze.
- Kierunek wiatru w czasie podróży liczy się po tym samym wektorze, między położeniami, a nie między komórkami.
- Decyzja zapadła, zanim ktokolwiek zaimplementował liczenie czasu podróży: klient go nie liczy, bo `arriveAt` przychodzi z serwera, a backend przechowuje `arriveAt`, ale nie ma jeszcze arytmetyki odległości. Artefakt `contract/world-parity.json` wymaga przegenerowania z przesunięciem każdej wyspy.
- Rozmiar komórki w kliencie jest związany z tą stałą przez wygląd: przy `CELL_SIZE = 448` px i największym promieniu wyspy obwódki wody przybrzeżnej zaczynają się stykać powyżej ~0,14. Pilnuje tego test klienta sprawdzający, że sąsiednie wyspy nie nachodzą na siebie; zmniejszenie komórki musi go przejść.
