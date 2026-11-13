# OSCam Stability 1.3.0

Wersja dla OpenATV na ARMv7 i ARM64. Bazuje na OSCam ze Streamboard
(commit 7476c3278853149e9beb6bba08f115763830ea0c). Licencja w [COPYING](COPYING).

## Zmiany

- Widoczny pasek przewijania na desktopie i stopka poniżej rozwijanych paneli.
- Jasny, kompaktowy widok Status i spójna tabela pełnego statusu, także na telefonie.
- Status pokazuje problemy na górze, filtruje po nazwie i umożliwia wstrzymanie odświeżania.
- Panel pokazuje czas ostatniej próbki i odczytu, stan połączenia, ECM i limity aktywnej konfiguracji.
- Po błędzie WebIF zachowuje poprzedni odczyt i wydłuża odstęp między próbami do 60 sekund.
- Status korzysta z aktualizacji danych zamiast automatycznego przeładowania całej strony.
- W standardowym trybie CCcam (bez extended mode) okresowa kontrola sprawdza także
  oczekiwanie na odpowiedź, nawet przy włączonym keepalive. Używa istniejącego progu
  `cccreconnect` (domyślnie 12000 ms) i istniejącej procedury ponownego połączenia.
  Kontrola jest okresowa, więc próg nie jest gwarantowanym momentem ponownego połączenia.
- Zerowy albo nieprawidłowo krótki `clienttimeout` wraca do domyślnych 5000 ms.
  Prawidłowe wartości zachowują dotychczasowe działanie.

## Instalacja i testy

Pakiet IPK korzysta z dotychczasowego katalogu konfiguracji. Instalacja aktualizacji
może zatrzymać proces na czas wymiany binarki. Po aktualizacji uruchom ponownie
`oscam-stability` w menu Softcam. Instrukcja kompilacji jest w
[openatv-package/BUILD.txt](openatv-package/BUILD.txt).

Kompilacje ARMv7 i ARM64 sprawdzono w QEMU. Panel sprawdzono w Chromium przy
320, 390 i 1440 px. Reakcję na brak odpowiedzi CCcam sprawdzono w symulacji.
Test odbioru na fizycznym dekoderze wymaga porównania przed i po aktualizacji.
